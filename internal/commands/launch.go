package commands

import (
	"fmt"
	"regexp"

	"github.com/Liquid4All/on-prem-stack/internal/docker"
	"github.com/Liquid4All/on-prem-stack/internal/env"
	"github.com/spf13/cobra"
)

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
- Load or create configuration file
- Create required Docker volumes
- Start all services using docker compose`,
		RunE: func(cmd *cobra.Command, args []string) error {
			upgradeStack, _ := cmd.Flags().GetBool("upgrade-stack")
			upgradeModel, _ := cmd.Flags().GetBool("upgrade-model")

			// Check if Docker is running
			if err := docker.CheckDockerRunning(); err != nil {
				return fmt.Errorf("docker check failed: %w", err)
			}

			// Load or create config
			cfg, err := env.LoadConfig()
			if err != nil {
				return fmt.Errorf("failed to load config: %w", err)
			}

			// Update stack and model versions if requested
			if upgradeStack {
				cfg.Stack.Version = "c3d7dbacd1"
			}
			if upgradeModel {
				cfg.Stack.Model.Image = "liquidai/lfm-7b-e:0.0.1"
				cfg.Stack.Model.Name = extractModelName(cfg.Stack.Model.Image)
			}

			// Save any changes to config
			if upgradeStack || upgradeModel {
				if err := cfg.Save(); err != nil {
					return fmt.Errorf("failed to save config: %w", err)
				}
				if err := cfg.ExportEnv(); err != nil {
					return fmt.Errorf("failed to export environment variables: %w", err)
				}
			}

			// Create postgres_data volume if it doesn't exist
			if err := docker.CreateVolume("postgres_data"); err != nil {
				return fmt.Errorf("failed to create postgres_data volume: %w", err)
			}

			// Start the stack
			if err := docker.ComposeUp("liquidai.yaml"); err != nil {
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
