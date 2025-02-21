package env

import (
	"fmt"
	"os"

	"github.com/Liquid4All/on-prem-stack/internal/config"
)

// LoadConfig loads the configuration and exports environment variables
func LoadConfig() (*config.Config, error) {
	cfg, err := config.Load()
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %w", err)
	}

	if err := cfg.ExportEnv(); err != nil {
		return nil, fmt.Errorf("failed to export environment variables: %w", err)
	}

	return cfg, nil
}

// SetEnvVar updates a configuration value and exports it as an environment variable
func SetEnvVar(name, value string, override bool) error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Update config based on variable name
	switch name {
	case "JWT_SECRET":
		if override || cfg.Security.JWTSecret == "" {
			cfg.Security.JWTSecret = value
		}
	case "API_SECRET":
		if override || cfg.Security.APISecret == "" {
			cfg.Security.APISecret = value
		}
	case "AUTH_SECRET":
		if override || cfg.Security.AuthSecret == "" {
			cfg.Security.AuthSecret = value
		}
	case "STACK_VERSION":
		if override || cfg.Stack.Version == "" {
			cfg.Stack.Version = value
		}
	case "MODEL_IMAGE":
		if override || cfg.Stack.Model.Image == "" {
			cfg.Stack.Model.Image = value
		}
	case "MODEL_NAME":
		if override || cfg.Stack.Model.Name == "" {
			cfg.Stack.Model.Name = value
		}
	case "POSTGRES_DB":
		if override || cfg.Database.Name == "" {
			cfg.Database.Name = value
		}
	case "POSTGRES_USER":
		if override || cfg.Database.User == "" {
			cfg.Database.User = value
		}
	case "POSTGRES_PASSWORD":
		if override || cfg.Database.Password == "" {
			cfg.Database.Password = value
		}
	case "POSTGRES_PORT":
		if override || cfg.Database.Port == 0 {
			cfg.Database.Port = 5432 // Always use default port
		}
	case "POSTGRES_SCHEMA":
		if override || cfg.Database.Schema == "" {
			cfg.Database.Schema = value
		}
	case "DATABASE_URL":
		if override || cfg.Database.URL == "" {
			cfg.Database.URL = value
		}
	default:
		return fmt.Errorf("unknown environment variable: %s", name)
	}

	// Save config and export environment variables
	if err := cfg.Save(); err != nil {
		return fmt.Errorf("failed to save config: %w", err)
	}

	if err := cfg.ExportEnv(); err != nil {
		return fmt.Errorf("failed to export environment variables: %w", err)
	}

	if override {
		fmt.Printf("%s in config is overridden with new value and exported\n", name)
	} else {
		fmt.Printf("%s already exists in config, the existing value is exported\n", name)
	}

	return nil
}
