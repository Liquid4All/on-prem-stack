package commands

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/Liquid4All/on-prem-stack/internal/docker"
	"github.com/Liquid4All/on-prem-stack/internal/env"
	"github.com/spf13/cobra"
)

func confirmAction() bool {
	fmt.Println("WARNING: This command will remove all Liquid Labs components:")
	fmt.Println("  - Stop and remove all containers")
	fmt.Println("  - Delete postgres_data volume (all database data will be lost)")
	fmt.Println("  - Remove liquid_labs_network")
	fmt.Println("  - Clean up dangling images")
	fmt.Println()
	fmt.Print("Are you sure you want to proceed? (y/N) ")

	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil {
		return false
	}

	response = strings.ToLower(strings.TrimSpace(response))
	return response == "y"
}

func NewPurgeCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "purge",
		Short: "Remove all Liquid Labs components",
		Long: `Remove all Liquid Labs components from the system.
This command will:
- Stop and remove all containers
- Delete postgres_data volume (all database data will be lost)
- Remove liquid_labs_network
- Clean up dangling images
- Remove .env file`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !confirmAction() {
				fmt.Println("Cleanup cancelled.")
				return nil
			}

			fmt.Println("Starting full cleanup of Liquid Labs stack...")

			// Shutdown all containers
			fmt.Println("Shutting down containers...")
			if err := docker.ComposeDown(env.EnvFile); err != nil {
				fmt.Printf("Warning: Failed to stop containers: %v\n", err)
			}

			// Remove the postgres volume
			fmt.Println("Removing postgres_data volume...")
			removeCmd := exec.Command("docker", "volume", "rm", "postgres_data")
			if err := removeCmd.Run(); err != nil {
				fmt.Printf("Warning: Failed to remove postgres_data volume: %v\n", err)
			} else {
				fmt.Println("postgres_data volume removed.")
			}

			// Remove the network
			fmt.Println("Removing liquid_labs_network...")
			networkCmd := exec.Command("docker", "network", "rm", "liquid_labs_network")
			if err := networkCmd.Run(); err != nil {
				fmt.Printf("Warning: Failed to remove liquid_labs_network: %v\n", err)
			} else {
				fmt.Println("liquid_labs_network removed.")
			}

			// Delete .env file
			fmt.Println("Deleting .env file...")
			if err := os.Remove(env.EnvFile); err != nil && !os.IsNotExist(err) {
				fmt.Printf("Warning: Failed to remove .env file: %v\n", err)
			}

			fmt.Println("Cleanup complete. All Liquid on-prem stack components have been removed.")
			return nil
		},
	}
}
