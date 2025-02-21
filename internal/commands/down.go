package commands

import (
	"fmt"
	"os"

	"github.com/Liquid4All/on-prem-stack/internal/docker"
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
			// Check if config file exists
			if _, err := os.Stat("liquidai.yaml"); os.IsNotExist(err) {
				return fmt.Errorf("error: liquidai.yaml does not exist. Please run the launch command first")
			}

			fmt.Println("Stopping the Liquid Labs stack...")
			if err := docker.ComposeDown("liquidai.yaml"); err != nil {
				return fmt.Errorf("failed to stop the stack: %w", err)
			}

			fmt.Println("Liquid Labs stack has been stopped.")
			fmt.Println("The postgres_data volume is not deleted. If needed, please remove it manually.")
			return nil
		},
	}
}
