package com.minhan.hrm.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;

@Configuration
@ConditionalOnProperty(prefix = "minhan.hrm.sso", name = "enabled", havingValue = "true")
public class SsoDataSourceConfig {

    @Bean(name = "ssoDataSource")
    public DataSource ssoDataSource(HrmProperties hrmProperties) {
        HrmProperties.Sso cfg = hrmProperties.getSso();
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(SqlServerJdbcUrl.build(cfg.getUrl()));
        ds.setUsername(cfg.getUsername());
        ds.setPassword(cfg.getPassword());
        ds.setDriverClassName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        ds.setMaximumPoolSize(3);
        ds.setMinimumIdle(0);
        ds.setPoolName("sso-pool");
        ds.setConnectionTimeout(15_000);
        ds.setInitializationFailTimeout(-1);
        return ds;
    }

    @Bean(name = "ssoJdbcTemplate")
    public JdbcTemplate ssoJdbcTemplate(@Qualifier("ssoDataSource") DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
