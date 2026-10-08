package com.forestarena.admin;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
@SpringBootApplication
public class AdminApplication {
 public static void main(String[] args) {
  SpringApplication app=new SpringApplication(AdminApplication.class);
  if(args.length>0 && java.util.Set.of("bootstrap","recover","key-init","key-rotate").contains(args[0])) app.setWebApplicationType(org.springframework.boot.WebApplicationType.NONE);
  app.run(args);
 }
}
