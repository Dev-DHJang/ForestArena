package com.forestarena.admin;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

public class DataApiException extends RuntimeException {
    final int status;
    public DataApiException(String code, int status) { super(code); this.status = status; }
}

@RestControllerAdvice(assignableTypes = AdminDataController.class)
class DataApiAdvice {
    @ExceptionHandler(DataApiException.class)
    @ResponseBody
    org.springframework.http.ResponseEntity<Map<String,String>> handle(DataApiException e) {
        return org.springframework.http.ResponseEntity.status(e.status).body(Map.of("error",e.getMessage()));
    }
    @ExceptionHandler({IllegalArgumentException.class, org.springframework.web.bind.MissingServletRequestParameterException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    Map<String,String> invalid(Exception e) { return Map.of("error","invalid_request"); }
}
