package com.forestarena.admin;
import org.junit.jupiter.api.Test;import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;import org.springframework.boot.SpringApplication;import java.nio.file.*;import java.nio.file.attribute.PosixFilePermissions;import java.util.*;
/** Explicitly enabled local browser-test fixtures. Never runs in the normal test suite. */
@EnabledIfEnvironmentVariable(named="ADMIN_E2E_FIXTURE_FILE",matches=".+")
class E2eFixtureTest {
 @Test void provision()throws Exception {
  String dbUrl=System.getenv("ADMIN_DB_URL");if(dbUrl==null||!dbUrl.endsWith("/forest_arena_admin_test_dev"))throw new IllegalStateException("브라우저 fixture는 전용 test DB에서만 허용합니다");
  var key=Path.of(System.getenv("ADMIN_KEY_FILE"));if(!Files.exists(key))new CryptoService(key.toString()).addKey(true);
  var app=new SpringApplication(AdminApplication.class);app.setWebApplicationType(org.springframework.boot.WebApplicationType.NONE);
  try(var ctx=app.run()){var service=ctx.getBean(AccountService.class);var db=service.db;StringBuilder env=new StringBuilder();String suffix=UUID.randomUUID().toString().substring(0,8);
   for(String role:List.of("SUPER_ADMIN","OPERATOR","VIEWER")){String label=role.equals("SUPER_ADMIN")?"SUPER":role;String login="e2e_"+label.toLowerCase()+"_"+suffix,pw=UUID.randomUUID().toString();var user=service.create(UUID.randomUUID(),Map.of("login_id",login,"password",pw,"display_name","브라우저 검사 "+label,"role",role,"reason","브라우저 자동 검사 fixture"),false);db.update("UPDATE admin.accounts SET must_change_password=false WHERE id=?",user.get("id"));env.append("ADMIN_E2E_").append(label).append("_ID='").append(login).append("'\nADMIN_E2E_").append(label).append("_PASSWORD='").append(pw).append("'\n");}
   var owner=new org.springframework.jdbc.datasource.DriverManagerDataSource(System.getenv("ADMIN_TEST_DATABASE_URL"),System.getenv("ADMIN_TEST_DATABASE_USER"),System.getenv("ADMIN_TEST_DATABASE_PASSWORD"));
   var ownerDb=new org.springframework.jdbc.core.JdbcTemplate(owner);UUID player=UUID.randomUUID();
   var fixture=ProfileValidator.JSON.readTree(getClass().getResourceAsStream("/profile-validation-fixtures.json")).get(0).get("profile");
   ownerDb.update("INSERT INTO app.players(player_id,display_name) VALUES(?,?)",player,"관리자 브라우저 검사");
   ownerDb.update("INSERT INTO app.player_profiles(player_id,profile) VALUES(?,?::jsonb)",player,fixture.toString());
   env.append("ADMIN_E2E_PLAYER_ID='").append(player).append("'\n");
   var output=Path.of(System.getenv("ADMIN_E2E_FIXTURE_FILE"));Path temp=Files.createTempFile(output.getParent(),".e2e-",".env",PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rw-------")));Files.writeString(temp,env.toString());Files.move(temp,output,StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING);
  }
 }
}
