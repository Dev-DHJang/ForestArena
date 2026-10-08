package com.forestarena.admin;
import org.springframework.http.*;import org.springframework.web.bind.annotation.*;import java.util.Map;
@RestControllerAdvice
public class AdminErrors {
 @ExceptionHandler(AdminFault.class) ResponseEntity<?> fault(AdminFault e){return ResponseEntity.status(e.status).body(Map.of("error",e.getMessage()));}
 @ExceptionHandler({IllegalArgumentException.class,org.springframework.http.converter.HttpMessageNotReadableException.class}) ResponseEntity<?> bad(Exception e){return ResponseEntity.badRequest().body(Map.of("error","입력값을 확인하세요"));}
 @ExceptionHandler(org.springframework.dao.DataAccessException.class) ResponseEntity<?> db(Exception e){return ResponseEntity.status(503).body(Map.of("error","데이터 처리에 실패했습니다"));}
}
class AdminFault extends RuntimeException {final int status;AdminFault(int status,String message){super(message);this.status=status;}}
