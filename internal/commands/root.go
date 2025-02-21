package commands

import (
	"github.com/spf13/cobra"
)

// RootCmd represents the base command when called without any subcommands
var RootCmd = &cobra.Command{
	Use:   "liquidai-cli",
	Short: "Liquid Labs on-prem deployment CLI",
	Long: `Command line interface for managing Liquid Labs on-prem deployment.
This CLI provides commands for managing the Liquid Labs on-prem stack,
including launching, shutting down, and managing models.`,
}

func init() {
	RootCmd.AddCommand(NewLaunchCmd())
}
