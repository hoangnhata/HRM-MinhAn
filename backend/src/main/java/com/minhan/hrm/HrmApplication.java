package com.minhan.hrm;

import com.minhan.hrm.config.LegacySqlServerTls;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class HrmApplication {

    public static void main(String[] args) {
        LegacySqlServerTls.enableForSqlServer2014();
        SpringApplication.run(HrmApplication.class, args);
    }
}
