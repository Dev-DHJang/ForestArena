package com.forestarena.admin;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.JsonNode;
class ProfileValidatorTest {
 @Test void sharedGameFixtures() throws Exception {
  ProfileValidator validator=new ProfileValidator();
  try(var stream=getClass().getResourceAsStream("/profile-validation-fixtures.json")) {
   for(JsonNode sample:ProfileValidator.JSON.readTree(stream)) {
    if(sample.get("valid").asBoolean()) assertDoesNotThrow(()->validator.validate(sample.get("profile")),sample.get("name").asText());
    else assertThrows(DataApiException.class,()->validator.validate(sample.get("profile")),sample.get("name").asText());
   }
  }
 }
 @Test void migrationAndCanonicalOrder() throws Exception {
  var p=ProfileValidator.JSON.readTree(getClass().getResourceAsStream("/profile-validation-fixtures.json")).get(0).get("profile").deepCopy();
  var old=(com.fasterxml.jackson.databind.node.ObjectNode)p;old.remove("nickname");old.remove("minimap");old.put("schema_version",2);
  assertEquals(3,new ProfileValidator().migrate(old).get("schema_version").asInt());assertEquals(2,old.get("schema_version").asInt());
  assertEquals(ProfileValidator.canonical(ProfileValidator.JSON.readTree("{\"b\":1.0,\"a\":[2]}")),ProfileValidator.canonical(ProfileValidator.JSON.readTree("{\"a\":[2],\"b\":1}")));
 }
}
