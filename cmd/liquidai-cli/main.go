package main

import (
    "fmt"
    "os"

    "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
    Use:   "liquidai-cli",
    Short: "Liquid Labs on-prem deployment CLI",
    Long:  `Command line interface for managing Liquid Labs on-prem deployment`,
}

func main() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Println(err)
        os.Exit(1)
    }
}
