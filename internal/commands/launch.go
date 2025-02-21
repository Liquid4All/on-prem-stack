package commands

import (
	"crypto/rand"
	"fmt"
	"os"
	"regexp"

	"github.com/Liquid4All/on-prem-stack/internal/docker"
	"github.com/Liquid4All/on-prem-stack/internal/env"
	"github.com/spf13/cobra"
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

func extractModelName(imageTag string) string {
	pattern := regexp.MustCompile(`liquidai/[^-]+-([^:]+)`)
	matches := pattern.FindStringSubmatch(imageTag)
	if len(matches) < 2 {
		return "lfm-7b" // Default value if pattern doesn't match
	}
	return matches[1]
}

func NewLaunchCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "launch",
		Short: "Launch the Liquid Labs stack",
		Long: `Launch the Liquid Labs on-prem deployment stack.
This command will:
- Create and populate the .env file if it doesn't exist
- Create required Docker volumes
- Start all services using docker compose`,
		RunE: func(cmd *cobra.Command, args []string) error {
			upgradeStack, _ := cmd.Flags().GetBool("upgrade-stack")
			upgradeModel, _ := cmd.Flags().GetBool("upgrade-model")

			// Check if Docker is running
			if err := docker.CheckDockerRunning(); err != nil {
				return fmt.Errorf("docker check failed: %w", err)
			}

			// Set required environment variables
			if err := env.SetEnvVar("JWT_SECRET", generateRandomString(64), false); err != nil {
				return fmt.Errorf("failed to set JWT_SECRET: %w", err)
			}

			if err := env.SetEnvVar("API_SECRET", "local_api_token", false); err != nil {
				return fmt.Errorf("failed to set API_SECRET: %w", err)
			}

			if err := env.SetEnvVar("AUTH_SECRET", generateRandomString(64), false); err != nil {
				return fmt.Errorf("failed to set AUTH_SECRET: %w", err)
			}

			// Set stack and model versions
			if err := env.SetEnvVar("STACK_VERSION", "c3d7dbacd1", upgradeStack); err != nil {
				return fmt.Errorf("failed to set STACK_VERSION: %w", err)
			}

			if err := env.SetEnvVar("MODEL_IMAGE", "liquidai/lfm-7b-e:0.0.1", upgradeModel); err != nil {
				return fmt.Errorf("failed to set MODEL_IMAGE: %w", err)
			}

			modelImage := os.Getenv("MODEL_IMAGE")
			modelName := extractModelName(modelImage)
			if err := env.SetEnvVar("MODEL_NAME", modelName, true); err != nil {
				return fmt.Errorf("failed to set MODEL_NAME: %w", err)
			}

			// Set database variables
			if err := env.SetEnvVar("POSTGRES_DB", "liquid_labs", false); err != nil {
				return fmt.Errorf("failed to set POSTGRES_DB: %w", err)
			}

			if err := env.SetEnvVar("POSTGRES_USER", "local_user", false); err != nil {
				return fmt.Errorf("failed to set POSTGRES_USER: %w", err)
			}

			if err := env.SetEnvVar("POSTGRES_PORT", "5432", false); err != nil {
				return fmt.Errorf("failed to set POSTGRES_PORT: %w", err)
			}

			if err := env.SetEnvVar("POSTGRES_SCHEMA", "labs", false); err != nil {
				return fmt.Errorf("failed to set POSTGRES_SCHEMA: %w", err)
			}

			if err := env.SetEnvVar("POSTGRES_PASSWORD", "local_password", false); err != nil {
				return fmt.Errorf("failed to set POSTGRES_PASSWORD: %w", err)
			}

			// Set DATABASE_URL
			dbURL := fmt.Sprintf("postgresql://%s:%s@liquid-labs-postgres:5432/%s",
				os.Getenv("POSTGRES_USER"),
				os.Getenv("POSTGRES_PASSWORD"),
				os.Getenv("POSTGRES_DB"))
			if err := env.SetEnvVar("DATABASE_URL", dbURL, true); err != nil {
				return fmt.Errorf("failed to set DATABASE_URL: %w", err)
			}

			// Create postgres_data volume if it doesn't exist
			if err := docker.CreateVolume("postgres_data"); err != nil {
				return fmt.Errorf("failed to create postgres_data volume: %w", err)
			}

			// Start the stack
			if err := docker.ComposeUp(env.EnvFile); err != nil {
				return fmt.Errorf("failed to start the stack: %w", err)
			}

			fmt.Println("The on-prem stack is now running.")
			return nil
		},
	}

	cmd.Flags().Bool("upgrade-stack", false, "Update stack version")
	cmd.Flags().Bool("upgrade-model", false, "Update model version")

	return cmd
}
