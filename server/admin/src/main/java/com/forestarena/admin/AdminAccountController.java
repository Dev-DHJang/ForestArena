package com.forestarena.admin;
import org.springframework.web.bind.annotation.*;import java.security.Principal;import java.util.*;
@RestController @RequestMapping("/admin/api/v1/admins")
public class AdminAccountController {
 final AccountService service;public AdminAccountController(AccountService s){service=s;}
 @GetMapping public Object list(@RequestParam(defaultValue="1") int page,@RequestParam(defaultValue="25")int size,@RequestParam(defaultValue="")String q){page=Math.max(1,page);size=Math.max(1,Math.min(size,100));if(q.length()>100)throw new AdminFault(400,"검색어가 너무 깁니다");String pattern="%"+q+"%";var rows=service.db.queryForList("SELECT * FROM admin.accounts WHERE login_id ILIKE ? ORDER BY created_at,id LIMIT ? OFFSET ?",pattern,size,(long)(page-1)*size);return Map.of("items",rows.stream().map(service::safe).toList(),"total",service.db.queryForObject("SELECT count(*) FROM admin.accounts WHERE login_id ILIKE ?",Long.class,pattern),"page",page,"size",size);}
 @PostMapping public Object create(Principal p,@RequestBody Map<String,Object>b){return service.create(UUID.fromString(p.getName()),b,false);}
 @PatchMapping("/{id}") public Object update(Principal p,@PathVariable UUID id,@RequestBody Map<String,Object>b){return service.edit(UUID.fromString(p.getName()),id,b);}
 @PostMapping("/{id}/reset-password") public Object reset(Principal p,@PathVariable UUID id,@RequestBody Map<String,Object>b){service.reset(UUID.fromString(p.getName()),id,AccountService.required(b,"temporary_password",128),AccountService.required(b,"reason",2000));return Map.of("ok",true);}
 @PostMapping("/{id}/end-sessions") public Object end(Principal p,@PathVariable UUID id,@RequestBody Map<String,Object>b){service.endSessions(UUID.fromString(p.getName()),id,AccountService.required(b,"reason",2000));return Map.of("ok",true);}
}
