package com.minhan.hrm.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;

@Configuration
@ConditionalOnProperty(prefix = "minhan.hrm.chamcong", name = "enabled", havingValue = "true")
public class ChamcongDataSourceConfig {

    @Bean(name = "chamcongDataSource")
    public DataSource chamcongDataSource(HrmProperties hrmProperties) {
        HrmProperties.Chamcong cfg = hrmProperties.getChamcong();
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(SqlServerJdbcUrl.build(cfg.getUrl()));
        ds.setUsername(cfg.getUsername());
        ds.setPassword(cfg.getPassword());
        ds.setDriverClassName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        ds.setMaximumPoolSize(3);
        ds.setMinimumIdle(0);
        ds.setPoolName("chamcong-pool");
        ds.setConnectionTimeout(15_000);
        // Không chặn khởi động app nếu SQL Server tạm không kết nối được
        ds.setInitializationFailTimeout(-1);
        return ds;
    }

    @Bean(name = "chamcongJdbcTemplate")
    public JdbcTemplate chamcongJdbcTemplate(@Qualifier("chamcongDataSource") DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
