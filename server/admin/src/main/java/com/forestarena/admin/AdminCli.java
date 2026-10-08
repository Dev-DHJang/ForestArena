package com.forestarena.admin;
import org.springframework.boot.CommandLineRunner;import org.springframework.stereotype.Component;import org.springframework.context.ConfigurableApplicationContext;import java.util.*;
@Component
public class AdminCli implements CommandLineRunner {
 final AccountService service;final CryptoService crypto;final ConfigurableApplicationContext context;
 public AdminCli(AccountService s,CryptoService c,ConfigurableApplicationContext context){service=s;crypto=c;this.context=context;}
 public void run(String...args){if(args.length==0||!Set.of("bootstrap","recover","key-init","key-rotate").contains(args[0]))return;
 try{switch(args[0]){
  case "key-init" -> crypto.addKey(true);
  case "key-rotate" -> crypto.rotate(service.db,service.tx);
  case "bootstrap" -> {if(args.length!=3)throw new IllegalArgumentException("bootstrap <login_id> <표시 이름>");String pw=hidden();service.create(null,Map.of("login_id",args[1],"display_name",args[2],"password",pw,"role","SUPER_ADMIN","reason","로컬 최초 계정 생성"),true);}
  case "recover" -> {if(args.length!=2)throw new IllegalArgumentException("recover <login_id>");service.recover(args[1],hidden());}
 }System.out.println("관리자 명령을 완료했습니다.");}finally{context.close();}}
 private String hidden(){var console=System.console();if(console==null)throw new IllegalStateException("비밀번호 숨김 입력을 위해 로컬 터미널에서 실행하세요");char[] a=console.readPassword("비밀번호 (15~128자): "),b=console.readPassword("비밀번호 확인: ");try{if(a==null||b==null||!Arrays.equals(a,b))throw new IllegalArgumentException("비밀번호가 일치하지 않습니다");String value=new String(a);AccountService.password(value);return value;}finally{if(a!=null)Arrays.fill(a,'\0');if(b!=null)Arrays.fill(b,'\0');}}
}
