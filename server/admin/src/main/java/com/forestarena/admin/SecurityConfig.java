package com.forestarena.admin;
import org.springframework.context.annotation.*;import org.springframework.security.config.annotation.web.builders.HttpSecurity;import org.springframework.security.web.*;import org.springframework.security.web.context.*;import org.springframework.security.web.access.intercept.AuthorizationFilter;import org.springframework.security.web.csrf.*;import org.springframework.web.filter.OncePerRequestFilter;import org.springframework.security.core.context.SecurityContextHolder;import jakarta.servlet.*;import jakarta.servlet.http.*;import org.springframework.jdbc.core.JdbcTemplate;import java.io.IOException;import java.security.MessageDigest;import java.nio.charset.StandardCharsets;import java.util.*;
@Configuration
@org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity
public class SecurityConfig {
 @Bean org.springframework.security.core.userdetails.UserDetailsService userDetailsService(){return name->{throw new org.springframework.security.core.userdetails.UsernameNotFoundException("계정 없음");};}
 @Bean SecurityContextRepository contextRepository(){return new HttpSessionSecurityContextRepository();}
 @Bean @org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication SecurityFilterChain security(HttpSecurity http,JdbcTemplate db,SecurityContextRepository repository)throws Exception{
  http.securityContext(c->c.securityContextRepository(repository)).authorizeHttpRequests(a->a
   .requestMatchers("/admin/api/v1/auth/csrf","/admin/api/v1/auth/login").permitAll()
   .requestMatchers("/admin/api/v1/admins/**").hasRole("SUPER_ADMIN")
   .requestMatchers(org.springframework.http.HttpMethod.PUT,"/admin/api/v1/profiles/**").hasAnyRole("SUPER_ADMIN","OPERATOR")
   .requestMatchers("/admin/api/**").authenticated().anyRequest().permitAll())
   .csrf(c->c.csrfTokenRepository(new HttpSessionCsrfTokenRepository()))
   .requestCache(c->c.disable()).formLogin(c->c.disable()).httpBasic(c->c.disable()).logout(c->c.disable())
   .exceptionHandling(e->e.authenticationEntryPoint((req,res,ex)->error(res,401,"로그인이 필요합니다")).accessDeniedHandler((req,res,ex)->error(res,403,"권한 또는 CSRF 토큰을 확인하세요")))
   .headers(h->h.contentSecurityPolicy(c->c.policyDirectives("default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'")))
   .addFilterBefore(new SessionGuard(db),AuthorizationFilter.class);
  return http.build();
 }
 static String digest(String s){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
 static void error(HttpServletResponse res,int status,String message)throws IOException{res.setStatus(status);res.setContentType("application/json;charset=UTF-8");res.getWriter().write("{\"error\":\""+message+"\"}");}
 static class SessionGuard extends OncePerRequestFilter {
  final JdbcTemplate db;SessionGuard(JdbcTemplate db){this.db=db;}
  protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain)throws ServletException,IOException{
   String host=req.getServerName();if(!Set.of("localhost","127.0.0.1","[::1]","::1").contains(host)){error(res,403,"허용되지 않은 접속 주소입니다");return;}
   String origin=req.getHeader("Origin");String expected=req.getScheme()+"://"+host+((req.getServerPort()==80||req.getServerPort()==443)?"":":"+req.getServerPort());
   if((origin!=null&&!origin.equals(expected))||"cross-site".equals(req.getHeader("Sec-Fetch-Site"))){error(res,403,"같은 출처에서 요청하세요");return;}
   var auth=SecurityContextHolder.getContext().getAuthentication();if(auth!=null&&auth.isAuthenticated()&&!auth.getName().equals("anonymousUser")){
    HttpSession session=req.getSession(false);boolean valid=false;Map<String,Object>a=null;
    if(session!=null){var rows=db.queryForList("SELECT a.id,a.must_change_password FROM admin.sessions s JOIN admin.accounts a ON a.id=s.account_id AND a.session_version=s.session_version WHERE s.id=? AND a.active AND s.created_at>now()-interval '8 hours' AND s.last_seen_at>now()-interval '30 minutes'",digest(session.getId()));if(!rows.isEmpty()){a=rows.getFirst();valid=a.get("id").toString().equals(auth.getName());}}
    if(!valid){if(session!=null)session.invalidate();SecurityContextHolder.clearContext();error(res,401,"세션이 만료되었습니다");return;}
    db.update("UPDATE admin.sessions SET last_seen_at=now() WHERE id=?",digest(session.getId()));
    if(Boolean.TRUE.equals(a.get("must_change_password"))&&!Set.of("/admin/api/v1/auth/me","/admin/api/v1/auth/csrf","/admin/api/v1/auth/password","/admin/api/v1/auth/logout").contains(req.getRequestURI())){error(res,403,"비밀번호 변경이 필요합니다");return;}
   }
   chain.doFilter(req,res);
  }
 }
}
