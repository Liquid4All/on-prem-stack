package main

import (
	"fmt"
	"os"

	"github.com/Liquid4All/on-prem-stack/internal/commands"
)

func main() {
	if err := commands.RootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
