package com.forestarena.admin;

import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Component;
import java.util.*;
import java.io.*;

/** Mirrors server/api/src/profiles.ts. The catalog is copied from that source by Maven. */
@Component
public class ProfileValidator {
    static final ObjectMapper JSON = new ObjectMapper();
    private final JsonNode catalog;
    public ProfileValidator() {
        try (InputStream stream = getClass().getResourceAsStream("/profile_catalog.json")) {
            if (stream == null) throw new IllegalStateException("profile catalog missing");
            catalog = JSON.readTree(stream);
        } catch (IOException e) { throw new IllegalStateException("profile catalog unreadable", e); }
    }
    public Object catalog() { return JSON.convertValue(catalog, Object.class); }
    private static void require(boolean ok) { if (!ok) throw new DataApiException("invalid_profile",400); }
    private static boolean shape(JsonNode n, String... keys) {
        if (n == null || !n.isObject() || n.size()!=keys.length) return false;
        for (String key:keys) if (!n.has(key)) return false;
        return true;
    }
    private boolean known(String kind, JsonNode id) { if(id == null || !id.isTextual()) return false; for(JsonNode candidate:catalog.get(kind)) if(candidate.equals(id)) return true; return false; }
    private static boolean contains(JsonNode ids, JsonNode id) { for (JsonNode item:ids) if(item.equals(id)) return true; return false; }
    public JsonNode migrate(JsonNode input) {
        JsonNode next=input.deepCopy();
        if (next.isObject() && next.path("schema_version").isNumber() && next.path("schema_version").asDouble()==2) {
            require(shape(next,"schema_version","first_granted","characters","accessories","selected_character","selected_accessory","opponent_character","accessibility"));
            ObjectNode o=(ObjectNode)next; o.put("schema_version",3); o.put("nickname","플레이어");
            o.set("minimap",JSON.createObjectNode().put("transparency",30).put("marker_style","face").put("show_names",true));
        }
        validate(next); return next;
    }
    public void validate(JsonNode p) {
        require(shape(p,"schema_version","first_granted","characters","accessories","selected_character","selected_accessory","opponent_character","accessibility","nickname","minimap"));
        require(p.get("schema_version").isNumber() && p.get("schema_version").asDouble()==3 && p.get("first_granted").isBoolean());
        for(String kind:List.of("characters","accessories")) {
            JsonNode ids=p.get(kind); require(ids.isArray()); Set<String> seen=new HashSet<>();
            for(JsonNode id:ids) require(known(kind,id) && seen.add(id.asText()));
        }
        require(p.get("selected_character").isTextual() && p.get("selected_accessory").isTextual() && known("characters",p.get("opponent_character")));
        require(p.get("first_granted").asBoolean() ? contains(p.get("characters"),p.get("selected_character")) : p.get("characters").isEmpty() && p.get("accessories").isEmpty() && p.get("selected_character").asText().isEmpty());
        require(p.get("selected_accessory").asText().isEmpty() || contains(p.get("accessories"),p.get("selected_accessory")));
        JsonNode a=p.get("accessibility"); require(shape(a,"text_scale","reduce_visual_effects","haptics_enabled"));
        require(a.get("text_scale").isNumber() && List.of(1d,1.15d,1.3d).contains(a.get("text_scale").asDouble()) && a.get("reduce_visual_effects").isBoolean() && a.get("haptics_enabled").isBoolean());
        JsonNode nickname=p.get("nickname"); require(nickname.isTextual()); String s=nickname.asText();
        require(!s.matches("(?s).*[\\x00-\\x1f\\x7f-\\x9f\\u2028\\u2029].*") && s.equals(s.replaceAll("^[\\s\\u00a0\\u1680\\u2000-\\u200a\\u202f\\u205f\\u3000\\ufeff]+|[\\s\\u00a0\\u1680\\u2000-\\u200a\\u202f\\u205f\\u3000\\ufeff]+$","")) && s.codePointCount(0,s.length())>=1 && s.codePointCount(0,s.length())<=12);
        JsonNode m=p.get("minimap"); require(shape(m,"transparency","marker_style","show_names"));
        JsonNode t=m.get("transparency"); require(t.isNumber() && t.asDouble()==Math.rint(t.asDouble()) && t.asDouble()>=0 && t.asDouble()<=90 && m.get("marker_style").isTextual() && List.of("face","dot").contains(m.get("marker_style").asText()) && m.get("show_names").isBoolean());
    }
    static String canonical(JsonNode n) {
        if(n.isObject()) { List<String> keys=new ArrayList<>(); n.fieldNames().forEachRemaining(keys::add); Collections.sort(keys); List<String> fields=new ArrayList<>(); for(String key:keys) fields.add(JSON.valueToTree(key).toString()+":"+canonical(n.get(key))); return "{"+String.join(",",fields)+"}"; }
        if(n.isArray()) { List<String> values=new ArrayList<>(); for(JsonNode item:n) values.add(canonical(item)); return "["+String.join(",",values)+"]"; }
        if(n.isNumber()) return n.decimalValue().stripTrailingZeros().toPlainString();
        return n.toString();
    }
}
