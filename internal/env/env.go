package env

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

const EnvFile = ".env"

// LoadEnvFile loads environment variables from .env file
func LoadEnvFile() error {
	file, err := os.Open(EnvFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // File doesn't exist is not an error
		}
		return fmt.Errorf("failed to open env file: %w", err)
	}
	defer file.Close()

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

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		os.Setenv(key, value)
	}

	return scanner.Err()
}

// SetEnvVar sets an environment variable in both the .env file and current process
func SetEnvVar(name, value string, override bool) error {
	// Check if file exists and create if it doesn't
	if _, err := os.Stat(EnvFile); os.IsNotExist(err) {
		file, err := os.Create(EnvFile)
		if err != nil {
			return fmt.Errorf("failed to create env file: %w", err)
		}
		file.Close()
	}

	// Read existing content
	content, err := os.ReadFile(EnvFile)
	if err != nil {
		return fmt.Errorf("failed to read env file: %w", err)
	}

	lines := strings.Split(string(content), "\n")
	found := false
	newLines := make([]string, 0, len(lines))

	// Process existing lines
	for _, line := range lines {
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, name+"=") {
			found = true
			if override {
				newLines = append(newLines, fmt.Sprintf("%s=%s", name, value))
				os.Setenv(name, value)
				fmt.Printf("%s in %s is overridden with new value and exported\n", name, EnvFile)
			} else {
				newLines = append(newLines, line)
				existingValue := strings.SplitN(line, "=", 2)[1]
				os.Setenv(name, existingValue)
				fmt.Printf("%s already exists in %s, the existing value is exported\n", name, EnvFile)
			}
		} else {
			newLines = append(newLines, line)
		}
	}

	// Add new variable if not found
	if !found {
		newLines = append(newLines, fmt.Sprintf("%s=%s", name, value))
		os.Setenv(name, value)
		fmt.Printf("%s is added to %s and exported\n", name, EnvFile)
	}

	// Write back to file
	output := strings.Join(newLines, "\n") + "\n"
	if err := os.WriteFile(EnvFile, []byte(output), 0644); err != nil {
		return fmt.Errorf("failed to write env file: %w", err)
	}

	return nil
}
