package config

import (
	"fmt"
	"os"

	"github.com/spf13/viper"
)

type Config struct {
	Version  int `yaml:"version"`
	Security struct {
		JWTSecret  string `yaml:"jwt_secret"`
		APISecret  string `yaml:"api_secret"`
		AuthSecret string `yaml:"auth_secret"`
	} `yaml:"security"`
	Stack struct {
		Version string `yaml:"version"`
		Model   struct {
			Image string `yaml:"image"`
			Name  string `yaml:"name"`
		} `yaml:"model"`
	} `yaml:"stack"`
	Database struct {
		Name     string `yaml:"name"`
		User     string `yaml:"user"`
		Password string `yaml:"password"`
		Port     int    `yaml:"port"`
		Schema   string `yaml:"schema"`
		URL      string `yaml:"url"`
	} `yaml:"database"`
}

const configFile = "liquidai.yaml"

// Load reads the config file from the current directory.
// If the config file doesn't exist, it attempts to migrate from .env
func Load() (*Config, error) {
	v := viper.New()
	v.SetConfigName("liquidai")
	v.SetConfigType("yaml")
	v.AddConfigPath(".")

	cfg := &Config{}

	// Try to read config
	if err := v.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			// Config doesn't exist, try to migrate from .env
			if err := migrateFromEnv(cfg); err != nil {
				return nil, fmt.Errorf("failed to migrate from .env: %w", err)
			}
			return cfg, nil
		}
		return nil, fmt.Errorf("failed to read config: %w", err)
	}

	if err := v.Unmarshal(cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config: %w", err)
	}

	return cfg, nil
}

// Save writes the config to the liquidai.yaml file
func (c *Config) Save() error {
	v := viper.New()
	v.SetConfigFile(configFile)
	
	if err := v.MergeConfigMap(map[string]interface{}{
		"version":  1,
		"security": c.Security,
		"stack":    c.Stack,
		"database": c.Database,
	}); err != nil {
		return fmt.Errorf("failed to merge config: %w", err)
	}

	return v.WriteConfig()
}

// ExportEnv exports all config values as environment variables
// This is needed for docker-compose compatibility
func (c *Config) ExportEnv() error {
	vars := map[string]string{
		"JWT_SECRET":      c.Security.JWTSecret,
		"API_SECRET":      c.Security.APISecret,
		"AUTH_SECRET":     c.Security.AuthSecret,
		"STACK_VERSION":   c.Stack.Version,
		"MODEL_IMAGE":     c.Stack.Model.Image,
		"MODEL_NAME":      c.Stack.Model.Name,
		"POSTGRES_DB":     c.Database.Name,
		"POSTGRES_USER":   c.Database.User,
		"POSTGRES_PORT":   fmt.Sprintf("%d", c.Database.Port),
		"POSTGRES_SCHEMA": c.Database.Schema,
		"POSTGRES_PASSWORD": c.Database.Password,
		"DATABASE_URL":    c.Database.URL,
	}

	for k, v := range vars {
		if err := os.Setenv(k, v); err != nil {
			return fmt.Errorf("failed to set environment variable %s: %w", k, err)
		}
	}

	return nil
}
