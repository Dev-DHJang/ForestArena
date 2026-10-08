package com.forestarena.admin;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;

@Service
public class AdminDataService {
    private final JdbcTemplate db;
    private final CryptoService crypto;
    private final ProfileValidator validator;
    private final String gameApi;
    public AdminDataService(JdbcTemplate db,CryptoService crypto,ProfileValidator validator,@Value("${admin.game-api-url:http://127.0.0.1:3000}") String gameApi) { this.db=db;this.crypto=crypto;this.validator=validator;this.gameApi=gameApi; }
    static UUID id(String value) { if(value==null || !value.matches("(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")) throw new DataApiException("invalid_id",400); return UUID.fromString(value); }
    static Object decode(Object raw) { try { return ProfileValidator.JSON.readValue(raw.toString(), Object.class); } catch(Exception e) { throw new IllegalStateException("stored JSON invalid",e); } }
    static JsonNode tree(Object value) { return ProfileValidator.JSON.valueToTree(value); }
    private Map<String,Object> safeRow(Map<String,Object> row) { Map<String,Object> out=new LinkedHashMap<>();row.forEach((k,v)-> { if(v==null) out.put(k,null); else if(List.of("profile","before_data","after_data","response").contains(k)) out.put(k,decode(v)); else if(v instanceof UUID || v instanceof java.util.Date || v instanceof java.time.temporal.TemporalAccessor) out.put(k,v.toString()); else out.put(k,v); }); if(out.containsKey("reason_encrypted")) { Object reason=out.remove("reason_encrypted");out.put("reason",reason==null?null:crypto.decrypt(reason.toString())); } return out; }
    private List<Map<String,Object>> rows(String sql,Object... args) { return db.queryForList(sql,args).stream().map(this::safeRow).toList(); }
    private Map<String,Object> one(String sql,Object...args) { List<Map<String,Object>> r=rows(sql,args);if(r.isEmpty()) throw new DataApiException("not_found",404);return r.getFirst(); }
    public Object catalog() { return validator.catalog(); }
    public Map<String,Object> page(String kind,String q,int page,int size) {
        if(page<1 || page>1000000 || size<1 || size>100 || q.length()>200) throw new DataApiException("invalid_page",400);
        String select,from,where,order;
        switch(kind) {
            case "guests" -> {select="p.player_id,p.display_name,p.created_at";from="app.players p";where="p.player_id::text ILIKE ? OR p.display_name ILIKE ?";order="p.created_at DESC,p.player_id";}
            case "profiles" -> {select="p.player_id,p.display_name,pr.profile,pr.revision,pr.updated_at";from="app.player_profiles pr JOIN app.players p USING(player_id)";where="p.player_id::text ILIKE ? OR p.display_name ILIKE ? OR pr.profile->>'nickname' ILIKE ?";order="pr.updated_at DESC,p.player_id";}
            case "matches" -> {select="m.*";from="app.matches m";where="m.match_id::text ILIKE ? OR m.status ILIKE ? OR EXISTS(SELECT 1 FROM app.match_participants part WHERE part.match_id=m.match_id AND part.player_id::text ILIKE ?)";order="m.created_at DESC,m.match_id";}
            case "audit" -> {select="a.*";from="admin.audit_log a";where="a.action ILIKE ? OR a.target_id ILIKE ? OR a.actor_id::text ILIKE ?";order="a.created_at DESC,a.id DESC";}
            default -> throw new DataApiException("not_found",404);
        }
        List<Object> args=new ArrayList<>(); for(int i=0;i<(kind.equals("guests")?2:3);i++) args.add("%"+q+"%");
        long total=db.queryForObject("SELECT count(*) FROM "+from+" WHERE "+where,Long.class,args.toArray());
        args.add(size);args.add((page-1)*size);
        return Map.of("items",rows("SELECT "+select+" FROM "+from+" WHERE "+where+" ORDER BY "+order+" LIMIT ? OFFSET ?",args.toArray()),"total",total,"page",page,"size",size);
    }
    public Map<String,Object> profile(String player) { Map<String,Object> saved=one("SELECT player_id,profile,revision FROM app.player_profiles WHERE player_id=?",id(player));saved.put("profile",ProfileValidator.JSON.convertValue(validator.migrate(tree(saved.get("profile"))),Object.class));return saved; }
    public Map<String,Object> guest(String player) { UUID uuid=id(player);Map<String,Object> result=new LinkedHashMap<>();result.put("player",one("SELECT player_id,display_name,created_at FROM app.players WHERE player_id=?",uuid));List<Map<String,Object>> profiles=rows("SELECT profile,revision FROM app.player_profiles WHERE player_id=?",uuid);result.put("profile",profiles.isEmpty()?null:ProfileValidator.JSON.convertValue(validator.migrate(tree(profiles.getFirst().get("profile"))),Object.class));result.put("revision",profiles.isEmpty()?null:profiles.getFirst().get("revision"));return result; }
    public Map<String,Object> match(String match) { UUID uuid=id(match);return Map.of("match",one("SELECT * FROM app.matches WHERE match_id=?",uuid),"participants",rows("SELECT part.*,p.display_name FROM app.match_participants part JOIN app.players p USING(player_id) WHERE match_id=? ORDER BY slot",uuid)); }
    @Transactional
    public Map<String,Object> update(String actor,String player,Map<String,Object> body) {
        UUID actorId=id(actor),playerId=id(player);JsonNode input=tree(body);
        if(!input.isObject() || input.size()!=4 || !input.has("request_id") || !input.get("request_id").isTextual() || !input.has("expected_revision") || !input.get("expected_revision").isNumber() || !input.get("expected_revision").canConvertToInt() || input.get("expected_revision").asDouble()!=input.get("expected_revision").asInt() || input.get("expected_revision").asInt()<1 || !input.has("reason") || !input.get("reason").isTextual() || input.get("reason").asText().isBlank() || input.get("reason").asText().length()>1000 || !input.has("profile")) throw new DataApiException("invalid_request",400);
        UUID request=id(input.get("request_id").asText());String hash;
        try { hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(ProfileValidator.canonical(input).getBytes(StandardCharsets.UTF_8))); } catch(Exception e) {throw new IllegalStateException(e);}
        Map<String,Object> current=one("SELECT profile,revision FROM app.player_profiles WHERE player_id=? FOR UPDATE",playerId);
        List<Map<String,Object>> prior=rows("SELECT request_hash,response FROM admin.requests WHERE actor_id=? AND player_id=? AND request_id=?",actorId,playerId,request);
        if(!prior.isEmpty()) { if(!hash.equals(prior.getFirst().get("request_hash"))) throw new DataApiException("request_id_conflict",409);return ProfileValidator.JSON.convertValue(prior.getFirst().get("response"),new com.fasterxml.jackson.core.type.TypeReference<Map<String,Object>>(){}); }
        int revision=((Number)current.get("revision")).intValue();if(revision!=input.get("expected_revision").asInt()) throw new DataApiException("revision_conflict",409);
        JsonNode before=validator.migrate(tree(current.get("profile"))),after=input.get("profile");validator.validate(after);
        if(!before.get("first_granted").equals(after.get("first_granted"))) throw new DataApiException("first_granted_immutable",400);
        if(revision==Integer.MAX_VALUE) throw new DataApiException("revision_limit",409);
        Map<String,Object> result=Map.of("profile",ProfileValidator.JSON.convertValue(after,Object.class),"revision",revision+1);
        db.update("UPDATE app.player_profiles SET profile=?::jsonb,revision=?,updated_at=now() WHERE player_id=?",after.toString(),revision+1,playerId);
        db.update("INSERT INTO admin.audit_log(actor_id,action,target_id,reason_encrypted,before_data,after_data) VALUES (?,'profile.update',?,?,?::jsonb,?::jsonb)",actorId,playerId.toString(),crypto.encrypt(input.get("reason").asText()),before.toString(),after.toString());
        db.update("INSERT INTO admin.requests(actor_id,player_id,request_id,request_hash,response) VALUES (?,?,?,?,?::jsonb)",actorId,playerId,request,hash,tree(result).toString());
        return result;
    }
    public Map<String,Object> dashboard() {
        Map<String,Object> out=new LinkedHashMap<>();
        try {
            out.put("guests",db.queryForObject("SELECT count(*) FROM app.players",Long.class));out.put("profiles",db.queryForObject("SELECT count(*) FROM app.player_profiles",Long.class));out.put("matches",db.queryForObject("SELECT count(*) FROM app.matches",Long.class));out.put("db_status","ok");
            out.put("recent_matches",rows("SELECT * FROM app.matches ORDER BY created_at DESC LIMIT 5"));out.put("recent_actions",rows("SELECT * FROM admin.audit_log ORDER BY created_at DESC,id DESC LIMIT 5"));
        } catch(org.springframework.dao.DataAccessException e) {
            out.put("guests",null);out.put("profiles",null);out.put("matches",null);out.put("db_status","unavailable");out.put("recent_matches",List.of());out.put("recent_actions",List.of());
        }
        String status="unavailable";
        try { URI base=URI.create(gameApi);if(!List.of("127.0.0.1","localhost","::1").contains(base.getHost())) throw new IllegalArgumentException("local API required");HttpRequest req=HttpRequest.newBuilder(base.resolve("/health/ready")).timeout(Duration.ofSeconds(2)).GET().build(); int code=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build().send(req,HttpResponse.BodyHandlers.discarding()).statusCode();if(code==200) status="ok"; } catch(Exception ignored) { }
        out.put("game_api_status",status);return out;
    }
}
