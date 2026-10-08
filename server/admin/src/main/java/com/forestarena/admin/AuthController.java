package com.forestarena.admin;
import org.springframework.web.bind.annotation.*;import org.springframework.security.web.csrf.CsrfToken;import org.springframework.security.web.context.SecurityContextRepository;import org.springframework.security.core.context.SecurityContextHolder;import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;import org.springframework.security.core.authority.SimpleGrantedAuthority;import jakarta.servlet.http.*;import java.security.Principal;import java.util.*;
@RestController @RequestMapping("/admin/api/v1/auth")
public class AuthController {
 final AccountService accounts;final SecurityContextRepository repository;
 public AuthController(AccountService accounts,SecurityContextRepository repository){this.accounts=accounts;this.repository=repository;}
 @GetMapping("/csrf") public Object csrf(CsrfToken token){return Map.of("token",token.getToken(),"headerName",token.getHeaderName());}
 @PostMapping("/login") public Object login(@RequestBody Map<String,Object>b,HttpServletRequest req,HttpServletResponse res){String login=AccountService.required(b,"login_id",80),password=AccountService.required(b,"password",128);String ip=req.getRemoteAddr();
  Map<String,Object> a=accounts.tx.execute(s->{accounts.db.execute("SELECT pg_advisory_xact_lock(74290124)");String ak=SecurityConfig.digest(login.toLowerCase(Locale.ROOT)),ik=SecurityConfig.digest(ip);
   for(var pair:List.of(new String[]{"account",ak},new String[]{"ip",ik})){accounts.db.update("INSERT INTO admin.login_limits(scope,key_hash,failures,window_started_at) VALUES(?,?,0,now()) ON CONFLICT DO NOTHING",pair[0],pair[1]);}
   if(accounts.db.queryForObject("SELECT count(*) FROM admin.login_limits WHERE ((scope='account' AND key_hash=?) OR (scope='ip' AND key_hash=?)) AND locked_until>now()",Long.class,ak,ik)>0)return null;
   var rows=accounts.db.queryForList("SELECT * FROM admin.accounts WHERE login_id=?",login);Map<String,Object> found=rows.isEmpty()?null:rows.getFirst();
   // Always perform a password hash check, including unknown accounts.
   String hash=found==null?DUMMY_HASH:(String)found.get("password_hash");boolean matched=accounts.encoder.matches(password,hash);
   accounts.db.update("UPDATE admin.login_limits SET failures=CASE WHEN window_started_at<now()-interval '15 minutes' THEN 1 ELSE failures+1 END,window_started_at=CASE WHEN window_started_at<now()-interval '15 minutes' THEN now() ELSE window_started_at END WHERE scope='ip' AND key_hash=?",ik);
   accounts.db.update("UPDATE admin.login_limits SET locked_until=now()+interval '15 minutes' WHERE scope='ip' AND key_hash=? AND failures>=30",ik);
   if(found==null||!matched||!Boolean.TRUE.equals(found.get("active"))){accounts.db.update("UPDATE admin.login_limits SET failures=CASE WHEN locked_until<=now() THEN 1 ELSE failures+1 END,locked_until=NULL WHERE scope='account' AND key_hash=?",ak);accounts.db.update("UPDATE admin.login_limits SET locked_until=now()+interval '15 minutes' WHERE scope='account' AND key_hash=? AND failures>=5",ak);return null;}
   accounts.db.update("UPDATE admin.login_limits SET failures=0,locked_until=NULL WHERE scope='account' AND key_hash=?",ak);return found;
  });
  if(a==null)throw new AdminFault(401,"로그인에 실패했거나 잠긴 계정입니다");
  if(req.getSession(false)!=null){accounts.db.update("DELETE FROM admin.sessions WHERE id=?",SecurityConfig.digest(req.getSession().getId()));SecurityConfig.invalidate(req.getSession(false));}var session=req.getSession(true);session.setMaxInactiveInterval(1800);
  accounts.db.update("INSERT INTO admin.sessions(id,account_id,session_version,created_at,last_seen_at) VALUES(?,?,?,now(),now())",SecurityConfig.digest(session.getId()),a.get("id"),a.get("session_version"));
  var context=SecurityContextHolder.createEmptyContext();context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(a.get("id").toString(),null,List.of(new SimpleGrantedAuthority("ROLE_"+a.get("role")))));SecurityContextHolder.setContext(context);repository.saveContext(context,req,res);return accounts.safe(a);
 }
 private static final String DUMMY_HASH=new org.springframework.security.crypto.argon2.Argon2PasswordEncoder(16,32,1,19456,2).encode("non-account-password-constant");
 @GetMapping("/me") public Object me(Principal p){return accounts.safe(accounts.row(UUID.fromString(p.getName())));}
 @PostMapping("/logout") public Object logout(HttpServletRequest req){var session=req.getSession(false);if(session!=null){accounts.db.update("DELETE FROM admin.sessions WHERE id=?",SecurityConfig.digest(session.getId()));SecurityConfig.invalidate(session);}SecurityContextHolder.clearContext();return Map.of("ok",true);}
 @PostMapping("/password") public Object password(Principal p,@RequestBody Map<String,Object>b,HttpServletRequest req){accounts.changePassword(UUID.fromString(p.getName()),AccountService.required(b,"current_password",128),AccountService.required(b,"new_password",128));SecurityConfig.invalidate(req.getSession(false));SecurityContextHolder.clearContext();return Map.of("ok",true);}
}
