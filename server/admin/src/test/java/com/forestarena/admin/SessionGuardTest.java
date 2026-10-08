package com.forestarena.admin;

import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class SessionGuardTest {
    @AfterEach void clearContext() { SecurityContextHolder.clearContext(); }
    private HttpServletRequest request(String uri) {
        var request=mock(HttpServletRequest.class);
        when(request.getServerName()).thenReturn("127.0.0.1");
        when(request.getScheme()).thenReturn("http");
        when(request.getServerPort()).thenReturn(8080);
        when(request.getRequestURI()).thenReturn(uri);
        SecurityContextHolder.getContext().setAuthentication(
            UsernamePasswordAuthenticationToken.authenticated("account-id",null,List.of()));
        return request;
    }
    @Test void publicFilesRemainAvailableWithAnExpiredAuthentication() throws Exception {
        var db=mock(JdbcTemplate.class);
        var request=request("/");
        var response=new MockHttpServletResponse();
        var chain=mock(FilterChain.class);
        new SecurityConfig.SessionGuard(db).doFilterInternal(request,response,chain);
        verify(chain).doFilter(request,response);
        verifyNoInteractions(db);
    }
    @Test void concurrentLogoutReturnsUnauthorizedWhenSessionWasAlreadyInvalidated() throws Exception {
        var db=mock(JdbcTemplate.class);
        var request=request("/admin/api/v1/auth/me");
        var session=mock(HttpSession.class);
        when(session.getId()).thenReturn("expired-session");
        when(request.getSession(false)).thenReturn(session);
        doThrow(new IllegalStateException("already invalidated")).when(session).invalidate();
        var response=new MockHttpServletResponse();
        var chain=mock(FilterChain.class);
        new SecurityConfig.SessionGuard(db).doFilterInternal(request,response,chain);
        assertEquals(401,response.getStatus());
        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verifyNoInteractions(chain);
    }
}
