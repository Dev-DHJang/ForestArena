package com.forestarena.admin;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.SecureRandom;
import java.util.*;
@Service
public class CryptoService {
 private final Path path; private final ObjectMapper json=new ObjectMapper(); private final SecureRandom random=new SecureRandom();
 public CryptoService(@Value("${admin.key-file}") String path){this.path=Path.of(path);}
 private synchronized Map<String,Object> read(){try {
  if(Files.isSymbolicLink(path)||!Files.getPosixFilePermissions(path).equals(PosixFilePermissions.fromString("rw-------"))) throw new IllegalStateException("키 파일은 일반 파일이며 권한 0600이어야 합니다");
  return json.readValue(Files.readString(path),Map.class);
 }catch(Exception e){throw new IllegalStateException("암호화 키 파일을 확인하세요",e);}}
 @SuppressWarnings("unchecked") public String encrypt(String value){if(value==null)return null;var data=read();String id=(String)data.get("active");var keys=(Map<String,String>)data.get("keys");try{
  byte[] iv=new byte[12];random.nextBytes(iv);Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key(keys.get(id)),new GCMParameterSpec(128,iv));c.updateAAD(id.getBytes(java.nio.charset.StandardCharsets.UTF_8));return id+":"+Base64.getEncoder().encodeToString(iv)+":"+Base64.getEncoder().encodeToString(c.doFinal(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
 }catch(Exception e){throw new IllegalStateException("암호화 실패",e);}}
 @SuppressWarnings("unchecked") public String decrypt(String value){if(value==null)return null;try{String[] p=value.split(":",-1);var keys=(Map<String,String>)read().get("keys");Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(keys.get(p[0])),new GCMParameterSpec(128,Base64.getDecoder().decode(p[1])));c.updateAAD(p[0].getBytes(java.nio.charset.StandardCharsets.UTF_8));return new String(c.doFinal(Base64.getDecoder().decode(p[2])),java.nio.charset.StandardCharsets.UTF_8);}catch(Exception e){throw new IllegalStateException("복호화 실패",e);}}
 private SecretKeySpec key(String s){byte[] b=Base64.getDecoder().decode(s);if(b.length!=32)throw new IllegalStateException("AES 키 길이 오류");return new SecretKeySpec(b,"AES");}
 @SuppressWarnings("unchecked") public synchronized void addKey(boolean first){try{
  Map<String,Object> data=first?new LinkedHashMap<>():read(); if(first&&Files.exists(path))throw new IllegalStateException("키 파일이 이미 있습니다");
  Map<String,String> keys=first?new LinkedHashMap<>():new LinkedHashMap<>((Map<String,String>)data.get("keys"));String id=UUID.randomUUID().toString();byte[] b=new byte[32];random.nextBytes(b);keys.put(id,Base64.getEncoder().encodeToString(b));data.put("active",id);data.put("keys",keys);
  Files.createDirectories(path.toAbsolutePath().getParent());Path tmp=Files.createTempFile(path.toAbsolutePath().getParent(),".admin-key-",".tmp",PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));Files.writeString(tmp,json.writeValueAsString(data));Files.move(tmp,path,StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING);
 }catch(Exception e){throw new IllegalStateException("키 생성 실패",e);}}
 public void rotate(JdbcTemplate db,TransactionTemplate tx){addKey(false);tx.executeWithoutResult(s->{
  for(var row:db.queryForList("SELECT id,display_name_encrypted,email_encrypted FROM admin.accounts FOR UPDATE")) db.update("UPDATE admin.accounts SET display_name_encrypted=?,email_encrypted=? WHERE id=?",encrypt(decrypt((String)row.get("display_name_encrypted"))),encrypt(decrypt((String)row.get("email_encrypted"))),row.get("id"));
  // Audit rows are append-only for the admin role. Old keys remain available for historical reasons.
 });}
}
