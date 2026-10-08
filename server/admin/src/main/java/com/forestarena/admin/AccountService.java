package com.forestarena.admin;
import org.springframework.stereotype.Service;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.transaction.support.TransactionTemplate;import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;import java.util.*;
@Service
public class AccountService {
 final JdbcTemplate db;final TransactionTemplate tx;final CryptoService crypto;
 final Argon2PasswordEncoder encoder=new Argon2PasswordEncoder(16,32,1,19456,2);
 static final Set<String> ROLES=Set.of("SUPER_ADMIN","OPERATOR","VIEWER");
 public AccountService(JdbcTemplate db,TransactionTemplate tx,CryptoService crypto){this.db=db;this.tx=tx;this.crypto=crypto;}
 static String required(Map<String,Object> b,String name,int max){Object v=b.get(name);if(!(v instanceof String s)||s.isBlank()||s.length()>max)throw new AdminFault(400,name+" 입력을 확인하세요");return (String)v;}
 static void password(String p){if(p==null||p.length()<15||p.length()>128)throw new AdminFault(400,"비밀번호는 15~128자여야 합니다");}
 Map<String,Object> row(UUID id){var rows=db.queryForList("SELECT * FROM admin.accounts WHERE id=?",id);if(rows.isEmpty())throw new AdminFault(404,"계정이 없습니다");return rows.getFirst();}
 Map<String,Object> locked(UUID id){var rows=db.queryForList("SELECT * FROM admin.accounts WHERE id=? FOR UPDATE",id);if(rows.isEmpty())throw new AdminFault(404,"계정이 없습니다");return rows.getFirst();}
 Map<String,Object> safe(Map<String,Object> a){Map<String,Object> m=new LinkedHashMap<>();for(String k:List.of("id","login_id","role","active","must_change_password"))m.put(k,a.get(k));m.put("display_name",crypto.decrypt((String)a.get("display_name_encrypted")));m.put("email",crypto.decrypt((String)a.get("email_encrypted")));return m;}
 void audit(UUID actor,String action,UUID target,String reason,Object before,Object after){try{var mapper=new com.fasterxml.jackson.databind.ObjectMapper();db.update("INSERT INTO admin.audit_log(actor_id,action,target_id,reason_encrypted,before_data,after_data) VALUES(?,?,?,?,?::jsonb,?::jsonb)",actor,action,target.toString(),crypto.encrypt(reason),mapper.writeValueAsString(before),mapper.writeValueAsString(after));}catch(com.fasterxml.jackson.core.JsonProcessingException e){throw new IllegalStateException(e);}}
 Object snapshot(Map<String,Object> r){return Map.of("login_id",r.get("login_id"),"role",r.get("role"),"active",r.get("active"),"must_change_password",r.get("must_change_password"));}
 public Map<String,Object> create(UUID actor,Map<String,Object>b,boolean bootstrap){String login=required(b,"login_id",80);if(!login.matches("[A-Za-z0-9._-]{3,80}"))throw new AdminFault(400,"로그인 ID 형식을 확인하세요");String name=required(b,"display_name",100), role=required(b,"role",20), pw=required(b,"password",128);password(pw);if(!ROLES.contains(role))throw new AdminFault(400,"권한 오류");String reason=required(b,"reason",2000);String email=email(b);return tx.execute(s->{
  db.execute("SELECT pg_advisory_xact_lock(74290123)");
  if(bootstrap&&db.queryForObject("SELECT count(*) FROM admin.accounts",Long.class)>0)throw new AdminFault(409,"최초 계정이 이미 있습니다");UUID id=UUID.randomUUID();
  db.update("INSERT INTO admin.accounts(id,login_id,password_hash,display_name_encrypted,email_encrypted,role,active,must_change_password) VALUES(?,?,?,?,?,?,true,?)",id,login,encoder.encode(pw),crypto.encrypt(name),crypto.encrypt(email),role,!bootstrap);
  audit(actor==null?id:actor,"ADMIN_CREATE",id,reason,null,Map.of("login_id",login,"role",role));return safe(row(id));
 });}
 private String email(Map<String,Object>b){Object e=b.get("email");if(e==null||e.equals(""))return null;if(!(e instanceof String s)||s.length()>254||!s.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+"))throw new AdminFault(400,"이메일 형식을 확인하세요");return (String)e;}
 public Map<String,Object> edit(UUID actor,UUID id,Map<String,Object>b){String name=required(b,"display_name",100),role=required(b,"role",20),reason=required(b,"reason",2000);if(!ROLES.contains(role)||!(b.get("active") instanceof Boolean))throw new AdminFault(400,"권한 또는 활성 상태 오류");boolean active=(Boolean)b.get("active");String email=email(b);return tx.execute(s->{
  db.execute("SELECT pg_advisory_xact_lock(74290123)");var before=locked(id);
  if(before.get("role").equals("SUPER_ADMIN")&&Boolean.TRUE.equals(before.get("active"))&&(!active||!role.equals("SUPER_ADMIN"))&&db.queryForObject("SELECT count(*) FROM admin.accounts WHERE role='SUPER_ADMIN' AND active",Long.class)<=1)throw new AdminFault(409,"마지막 활성 최고관리자를 변경할 수 없습니다");
  boolean revoke=!role.equals(before.get("role"))||active!=Boolean.TRUE.equals(before.get("active"));
  db.update("UPDATE admin.accounts SET display_name_encrypted=?,email_encrypted=?,role=?,active=?,session_version=session_version+?,updated_at=now() WHERE id=?",crypto.encrypt(name),crypto.encrypt(email),role,active,revoke?1:0,id);
  if(revoke)db.update("DELETE FROM admin.sessions WHERE account_id=?",id);audit(actor,"ADMIN_UPDATE",id,reason,snapshot(before),snapshot(row(id)));return safe(row(id));
 });}
 public void reset(UUID actor,UUID id,String pw,String reason){password(pw);tx.executeWithoutResult(s->{locked(id);db.update("UPDATE admin.accounts SET password_hash=?,must_change_password=true,session_version=session_version+1,updated_at=now() WHERE id=?",encoder.encode(pw),id);db.update("DELETE FROM admin.sessions WHERE account_id=?",id);audit(actor,"ADMIN_PASSWORD_RESET",id,reason,null,Map.of("must_change_password",true));});}
 public void recover(String login,String pw){password(pw);tx.executeWithoutResult(s->{
  db.execute("SELECT pg_advisory_xact_lock(74290123)");
  var rows=db.queryForList("SELECT id FROM admin.accounts WHERE login_id=?",login);if(rows.isEmpty())throw new AdminFault(404,"계정이 없습니다");UUID id=(UUID)rows.getFirst().get("id");var before=locked(id);
  db.update("UPDATE admin.accounts SET active=true,role='SUPER_ADMIN' WHERE id=?",id);
  reset(id,id,pw,"로컬 복구 명령");
  db.update("DELETE FROM admin.login_limits WHERE scope='account' AND key_hash=?",SecurityConfig.digest(login.toLowerCase(Locale.ROOT)));
  audit(id,"ADMIN_RECOVER",id,"로컬 계정 복구",snapshot(before),snapshot(row(id)));
 });}
 public void changePassword(UUID id,String old,String pw){password(pw);tx.executeWithoutResult(s->{var a=locked(id);if(!encoder.matches(old,(String)a.get("password_hash")))throw new AdminFault(400,"현재 비밀번호가 올바르지 않습니다");if(encoder.matches(pw,(String)a.get("password_hash")))throw new AdminFault(400,"기존 비밀번호와 다른 값을 입력하세요");db.update("UPDATE admin.accounts SET password_hash=?,must_change_password=false,session_version=session_version+1,updated_at=now() WHERE id=?",encoder.encode(pw),id);db.update("DELETE FROM admin.sessions WHERE account_id=?",id);audit(id,"ADMIN_PASSWORD_CHANGE",id,"본인 비밀번호 변경",null,null);});}
 public void endSessions(UUID actor,UUID id,String reason){tx.executeWithoutResult(s->{locked(id);db.update("UPDATE admin.accounts SET session_version=session_version+1 WHERE id=?",id);db.update("DELETE FROM admin.sessions WHERE account_id=?",id);audit(actor,"ADMIN_END_SESSIONS",id,reason,null,null);});}
}
