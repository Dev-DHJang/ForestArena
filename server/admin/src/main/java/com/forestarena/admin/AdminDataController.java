package com.forestarena.admin;

import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import java.security.Principal;
import java.util.Map;

@RestController
@RequestMapping("/admin/api/v1")
@PreAuthorize("hasAnyRole('SUPER_ADMIN','OPERATOR','VIEWER')")
public class AdminDataController {
    private final AdminDataService service;
    public AdminDataController(AdminDataService service) {this.service=service;}
    @GetMapping("/catalog") public Object catalog() {return service.catalog();}
    @GetMapping("/dashboard") public Object dashboard() {return service.dashboard();}
    @GetMapping({"/guests","/profiles","/matches","/audit"}) public Object list(jakarta.servlet.http.HttpServletRequest request,@RequestParam(defaultValue="") String q,@RequestParam(defaultValue="1") int page,@RequestParam(defaultValue="25") int size) {return service.page(request.getRequestURI().substring(request.getRequestURI().lastIndexOf('/')+1),q,page,size);}
    @GetMapping("/guests/{id}") public Object guest(@PathVariable String id) {return service.guest(id);}
    @GetMapping("/profiles/{id}") public Object profile(@PathVariable String id) {return service.profile(id);}
    @GetMapping("/matches/{id}") public Object match(@PathVariable String id) {return service.match(id);}
    @PutMapping("/profiles/{id}") @PreAuthorize("hasAnyRole('SUPER_ADMIN','OPERATOR')") public Object update(@PathVariable String id,@RequestBody Map<String,Object> body,Principal principal) {return service.update(principal.getName(),id,body);}
}
