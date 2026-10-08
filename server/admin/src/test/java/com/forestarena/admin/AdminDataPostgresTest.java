package com.forestarena.admin;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

/** Dedicated, random test rows; uses an owner connection only to set up and remove those rows. */
@EnabledIfEnvironmentVariable(named="ADMIN_TEST_DATABASE_URL",matches=".+")
class AdminDataPostgresTest {
 JdbcTemplate db;TransactionTemplate tx;AdminDataService service;UUID actor,player;Map<String,Object> fresh;Path key;
 @BeforeEach void setup() throws Exception {
  var ds=new DriverManagerDataSource(System.getenv("ADMIN_TEST_DATABASE_URL"),System.getenv("ADMIN_TEST_DATABASE_USER"),System.getenv("ADMIN_TEST_DATABASE_PASSWORD"));db=new JdbcTemplate(ds);tx=new TransactionTemplate(new DataSourceTransactionManager(ds));
  key=Files.createTempDirectory("forest-admin-data-test-").resolve("keys.json");var crypto=new CryptoService(key.toString());crypto.addKey(true);service=new AdminDataService(db,crypto,new ProfileValidator(),"http://127.0.0.1:1");
  actor=UUID.randomUUID();player=UUID.randomUUID();
  db.update("INSERT INTO admin.accounts(id,login_id,password_hash,display_name_encrypted,role,active,must_change_password) VALUES (?,?,?,?, 'OPERATOR',true,false)",actor,"test-"+actor,"not-a-real-hash",crypto.encrypt("통합 검사"));
  db.update("INSERT INTO app.players(player_id,display_name) VALUES (?,?)",player,"admin-integration-"+player.toString().substring(0,8));
  var examples=ProfileValidator.JSON.readTree(getClass().getResourceAsStream("/profile-validation-fixtures.json"));fresh=ProfileValidator.JSON.convertValue(examples.get(0).get("profile"),Map.class);
  db.update("INSERT INTO app.player_profiles(player_id,profile) VALUES (?,?::jsonb)",player,AdminDataService.tree(fresh).toString());
 }
 @AfterEach void cleanup() throws Exception {
  if(db!=null && actor!=null){db.update("DELETE FROM admin.requests WHERE actor_id=?",actor);db.update("DELETE FROM admin.audit_log WHERE actor_id=? OR target_id=?",actor,player.toString());db.update("DELETE FROM app.player_profiles WHERE player_id=?",player);db.update("DELETE FROM app.players WHERE player_id=?",player);db.update("DELETE FROM admin.accounts WHERE id=?",actor);}
  if(key!=null) {Files.deleteIfExists(key);Files.deleteIfExists(key.getParent());}
 }
 Map<String,Object> body(int revision,String nickname) {var p=new LinkedHashMap<>(fresh);p.put("nickname",nickname);return new LinkedHashMap<>(Map.of("request_id",UUID.randomUUID().toString(),"expected_revision",revision,"reason","통합 검사 사유","profile",p));}
 Map<String,Object> update(Map<String,Object> body) {return tx.execute(s->service.update(actor.toString(),player.toString(),body));}
 @Test void revisionIdempotencyAuditAndRollback() {
  var body=body(1,"숲지기");var result=update(body);assertEquals(2,result.get("revision"));
  assertEquals(result,update(new TreeMap<>(body)));
  assertEquals(1,db.queryForObject("SELECT count(*) FROM admin.audit_log WHERE actor_id=?",Integer.class,actor));
  assertFalse(db.queryForObject("SELECT reason_encrypted FROM admin.audit_log WHERE actor_id=?",String.class,actor).contains("통합 검사"));
  var conflict=new LinkedHashMap<>(body);conflict.put("reason","다른 사유");assertEquals(409,assertThrows(DataApiException.class,()->update(conflict)).status);
  assertEquals(409,assertThrows(DataApiException.class,()->update(body(1,"오래된 수정"))).status);
  var invalid=body(2,"불가");((Map<String,Object>)invalid.get("profile")).put("selected_character","nabi");assertThrows(DataApiException.class,()->update(invalid));
  var first=body(2,"불가");((Map<String,Object>)first.get("profile")).put("first_granted",true);((Map<String,Object>)first.get("profile")).put("characters",List.of("nabi"));((Map<String,Object>)first.get("profile")).put("selected_character","nabi");assertEquals("first_granted_immutable",assertThrows(DataApiException.class,()->update(first)).getMessage());
  // Fail only this test player's audit insert after UPDATE, then ensure full rollback.
  String trigger="test_audit_"+player.toString().replace("-", "");
  db.execute("CREATE FUNCTION admin."+trigger+"() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.target_id = '"+player+"' THEN RAISE EXCEPTION 'test audit failure'; END IF; RETURN NEW; END $$");
  db.execute("CREATE TRIGGER "+trigger+" BEFORE INSERT ON admin.audit_log FOR EACH ROW EXECUTE FUNCTION admin."+trigger+"()");
  try { assertThrows(org.springframework.dao.DataAccessException.class,()->update(body(2,"취소되어야 함"))); }
  finally {db.execute("DROP TRIGGER "+trigger+" ON admin.audit_log");db.execute("DROP FUNCTION admin."+trigger+"()");}
  assertEquals(2,db.queryForObject("SELECT revision FROM app.player_profiles WHERE player_id=?",Integer.class,player));
  assertEquals("숲지기",((Map<?,?>)service.profile(player.toString()).get("profile")).get("nickname"));
  assertEquals(0,db.queryForObject("SELECT count(*) FROM app.profile_requests WHERE player_id=?",Integer.class,player));
 }
 @Test void gameAndAdminConcurrentUpdatesDetectRevision() throws Exception {
  CountDownLatch locked=new CountDownLatch(1),release=new CountDownLatch(1);ExecutorService pool=Executors.newFixedThreadPool(2);
  try {
   Future<?> game=pool.submit(()->tx.execute(s->{db.queryForObject("SELECT revision FROM app.player_profiles WHERE player_id=? FOR UPDATE",Integer.class,player);locked.countDown();try {assertTrue(release.await(5,TimeUnit.SECONDS));}catch(InterruptedException e){throw new RuntimeException(e);}db.update("UPDATE app.player_profiles SET revision=revision+1 WHERE player_id=?",player);return null;}));
   assertTrue(locked.await(5,TimeUnit.SECONDS));Future<?> admin=pool.submit(()->assertEquals(409,assertThrows(DataApiException.class,()->update(body(1,"동시 변경"))).status));release.countDown();game.get(10,TimeUnit.SECONDS);admin.get(10,TimeUnit.SECONDS);
   assertEquals(2,db.queryForObject("SELECT revision FROM app.player_profiles WHERE player_id=?",Integer.class,player));
  } finally {release.countDown();pool.shutdownNow();}
 }
 @Test void listBoundsSearchAndDetails() {
  assertThrows(DataApiException.class,()->service.page("guests","",1,101));assertThrows(DataApiException.class,()->service.page("audit","",0,25));
  assertEquals(1L,service.page("guests",player.toString(),1,25).get("total"));assertNotNull(service.guest(player.toString()).get("profile"));
  assertEquals(0L,service.page("profiles","' OR 1=1 --",1,25).get("total"));
 }
}
