package commands

import (
	"fmt"
	"os"

	"github.com/Liquid4All/on-prem-stack/internal/docker"
	"github.com/Liquid4All/on-prem-stack/internal/env"
	"github.com/spf13/cobra"
)

func NewDownCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "down",
		Short: "Stop the Liquid Labs stack",
		Long: `Stop the Liquid Labs on-prem deployment stack.
This command will:
- Stop all running containers
- Remove containers (but preserve volumes)
- Keep the postgres_data volume intact`,
		RunE: func(cmd *cobra.Command, args []string) error {
			// Check if .env file exists
			if _, err := os.Stat(env.EnvFile); os.IsNotExist(err) {
				return fmt.Errorf("error: %s does not exist. Please run the launch command first", env.EnvFile)
			}

			fmt.Println("Stopping the Liquid Labs stack...")
			if err := docker.ComposeDown(env.EnvFile); err != nil {
				return fmt.Errorf("failed to stop the stack: %w", err)
			}

			fmt.Println("Liquid Labs stack has been stopped.")
			fmt.Println("The postgres_data volume is not deleted. If needed, please remove it manually.")
			return nil
		},
	}
}
