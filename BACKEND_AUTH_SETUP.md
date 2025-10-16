# Backend Authentication Setup (Java/Spring Boot)

This guide explains how to set up authentication in your Java/Spring Boot backend to work with Keycloak.

## Prerequisites

- Java 17+
- Spring Boot 3.x
- Maven or Gradle
- Keycloak running and configured (see KEYCLOAK_SETUP.md)

## Step 1: Add Dependencies

### Maven (pom.xml)

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>

<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-spring-boot-starter</artifactId>
    <version>26.4.0</version>
</dependency>

<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-admin-client</artifactId>
    <version>26.4.0</version>
</dependency>
```

### Gradle (build.gradle)

```gradle
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'
    implementation 'org.springframework.boot:spring-boot-starter-security'
    implementation 'org.keycloak:keycloak-spring-boot-starter:26.4.0'
    implementation 'org.keycloak:keycloak-admin-client:26.4.0'
}
```

## Step 2: Configure application.yml

```yaml
spring:
  application:
    name: airo-backend
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8080/realms/example
          jwk-set-uri: http://localhost:8080/realms/example/protocol/openid-connect/certs

keycloak:
  realm: example
  auth-server-url: http://localhost:8080
  ssl-required: none
  resource: backend
  credentials:
    secret: ${KEYCLOAK_CLIENT_SECRET}
  use-resource-role-mappings: true
  bearer-only: true

server:
  port: 8081
```

## Step 3: Create Security Configuration

```java
package com.airo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors()
            .and()
            .csrf().disable()
            .sessionManagement()
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            .and()
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer()
                .jwt();

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(Arrays.asList(
            "http://localhost:3000",
            "http://localhost:8888",
            "http://localhost:8080"
        ));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
```

## Step 4: Create Authentication Controller

```java
package com.airo.controller;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @GetMapping("/me")
    public UserInfoResponse getCurrentUser(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        
        return UserInfoResponse.builder()
            .id(jwt.getClaimAsString("sub"))
            .username(jwt.getClaimAsString("preferred_username"))
            .email(jwt.getClaimAsString("email"))
            .firstName(jwt.getClaimAsString("given_name"))
            .lastName(jwt.getClaimAsString("family_name"))
            .roles(jwt.getClaimAsStringList("roles"))
            .build();
    }

    @PostMapping("/validate-token")
    public TokenValidationResponse validateToken(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        
        return TokenValidationResponse.builder()
            .valid(true)
            .expiresAt(jwt.getExpiresAt())
            .issuedAt(jwt.getIssuedAt())
            .build();
    }

    @PostMapping("/refresh")
    public void refreshToken() {
        // Token refresh is handled by Keycloak
        // This endpoint can be used to trigger token refresh on client side
    }
}
```

## Step 5: Create DTOs

```java
package com.airo.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserInfoResponse {
    private String id;
    private String username;
    private String email;
    private String firstName;
    private String lastName;
    private List<String> roles;
}

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TokenValidationResponse {
    private boolean valid;
    private Instant expiresAt;
    private Instant issuedAt;
}
```

## Step 6: Create Custom JWT Claims Extractor (Optional)

```java
package com.airo.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

@Component
public class JwtClaimsExtractor {

    public String getUserId(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        return jwt.getClaimAsString("sub");
    }

    public String getUsername(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        return jwt.getClaimAsString("preferred_username");
    }

    public String getEmail(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        return jwt.getClaimAsString("email");
    }

    public List<String> getRoles(Authentication authentication) {
        Jwt jwt = (Jwt) authentication.getPrincipal();
        return jwt.getClaimAsStringList("roles");
    }

    public boolean hasRole(Authentication authentication, String role) {
        return getRoles(authentication).contains(role);
    }
}
```

## Step 7: Create Protected Endpoints

```java
package com.airo.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/chats")
public class ChatController {

    @GetMapping
    @PreAuthorize("hasRole('user')")
    public List<ChatResponse> getUserChats(Authentication authentication) {
        String userId = authentication.getName();
        // Fetch chats for user
        return chatService.getUserChats(userId);
    }

    @PostMapping
    @PreAuthorize("hasRole('user')")
    public ChatResponse createChat(
        @RequestBody CreateChatRequest request,
        Authentication authentication
    ) {
        String userId = authentication.getName();
        return chatService.createChat(userId, request);
    }

    @GetMapping("/{chatId}")
    @PreAuthorize("hasRole('user')")
    public ChatResponse getChat(
        @PathVariable String chatId,
        Authentication authentication
    ) {
        String userId = authentication.getName();
        return chatService.getChat(chatId, userId);
    }
}
```

## Step 8: Environment Variables

Create `.env` file:

```env
KEYCLOAK_CLIENT_SECRET=your-client-secret-from-keycloak
KEYCLOAK_REALM=example
KEYCLOAK_AUTH_SERVER_URL=http://localhost:8080
```

## Step 9: Run Backend

```bash
# Set environment variables
export KEYCLOAK_CLIENT_SECRET=your-secret

# Run with Maven
mvn spring-boot:run

# Or with Gradle
gradle bootRun
```

Backend will be available at: `http://localhost:8081`

## Testing Endpoints

### Get Current User Info

```bash
curl -H "Authorization: Bearer <access_token>" \
  http://localhost:8081/api/auth/me
```

### Validate Token

```bash
curl -X POST \
  -H "Authorization: Bearer <access_token>" \
  http://localhost:8081/api/auth/validate-token
```

## Security Best Practices

1. **Use HTTPS in production** - Set `ssl-required: all` in Keycloak
2. **Validate token signature** - Spring Security does this automatically
3. **Check token expiration** - Implement token refresh logic
4. **Use role-based access control** - Use `@PreAuthorize` annotations
5. **Log security events** - Monitor authentication failures
6. **Implement rate limiting** - Prevent brute force attacks
7. **Use strong secrets** - Generate secure client secrets

## Troubleshooting

### "Invalid token"
- Ensure Keycloak is running
- Check token hasn't expired
- Verify issuer URI matches Keycloak configuration

### "CORS errors"
- Update `corsConfigurationSource()` with correct origins
- Ensure preflight requests are allowed

### "401 Unauthorized"
- Check Authorization header format: `Bearer <token>`
- Verify token is valid and not expired

