package config

import (
	"bufio"
	"crypto/rand"
	"fmt"
	"os"
	"strings"
)

func generateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		randomBytes := make([]byte, 1)
		if _, err := rand.Read(randomBytes); err != nil {
			panic(err) // This should never happen
		}
		b[i] = charset[randomBytes[0]%byte(len(charset))]
	}
	return string(b)
}

func initDefaultConfig(cfg *Config) error {
	cfg.Version = 1
	cfg.Security.JWTSecret = generateRandomString(64)
	cfg.Security.APISecret = "local_api_token"
	cfg.Security.AuthSecret = generateRandomString(64)
	cfg.Stack.Version = "c3d7dbacd1"
	cfg.Stack.Model.Image = "liquidai/lfm-7b-e:0.0.1"
	cfg.Stack.Model.Name = "7b-e"
	cfg.Database.Name = "liquid_labs"
	cfg.Database.User = "local_user"
	cfg.Database.Password = "local_password"
	cfg.Database.Port = 5432
	cfg.Database.Schema = "labs"
	cfg.Database.URL = fmt.Sprintf("postgresql://%s:%s@liquid-labs-postgres:%d/%s",
		cfg.Database.User,
		cfg.Database.Password,
		cfg.Database.Port,
		cfg.Database.Name)

	return cfg.Save()
}

func migrateFromEnv(cfg *Config) error {
	if _, err := os.Stat(".env"); os.IsNotExist(err) {
		return initDefaultConfig(cfg)
	}

	file, err := os.Open(".env")
	if err != nil {
		return fmt.Errorf("failed to open .env: %w", err)
	}
	defer file.Close()

	envVars := make(map[string]string)
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		envVars[parts[0]] = parts[1]
	}

	cfg.Version = 1
	cfg.Security.JWTSecret = envVars["JWT_SECRET"]
	cfg.Security.APISecret = envVars["API_SECRET"]
	cfg.Security.AuthSecret = envVars["AUTH_SECRET"]
	cfg.Stack.Version = envVars["STACK_VERSION"]
	cfg.Stack.Model.Image = envVars["MODEL_IMAGE"]
	cfg.Stack.Model.Name = envVars["MODEL_NAME"]
	cfg.Database.Name = envVars["POSTGRES_DB"]
	cfg.Database.User = envVars["POSTGRES_USER"]
	cfg.Database.Password = envVars["POSTGRES_PASSWORD"]
	cfg.Database.Port = 5432
	cfg.Database.Schema = envVars["POSTGRES_SCHEMA"]
	cfg.Database.URL = envVars["DATABASE_URL"]

	if err := cfg.Save(); err != nil {
		return fmt.Errorf("failed to save migrated config: %w", err)
	}

	// Backup and remove .env
	if err := os.Rename(".env", ".env.bak"); err != nil {
		return fmt.Errorf("failed to backup .env: %w", err)
	}

	return nil
}
