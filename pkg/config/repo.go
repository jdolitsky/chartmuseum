package config

import (
	"fmt"
	"github.com/ghodss/yaml"
	"strings"
)

type (
	RepoConfig struct {
		AnonymousGet bool `yaml:"anonymousget"`
	}
)

func (conf *Config) GetRepoConfig(repo string) (*RepoConfig, error) {
	repoConfig := &RepoConfig{
		AnonymousGet: conf.GetBool("anonymousget"),
	}
	key := fmt.Sprintf("repos.%s", strings.Replace(repo, "/", ".", -1))
	raw := conf.GetString(key)
	if raw == "" {
		return repoConfig, nil
	}
	err := yaml.Unmarshal([]byte(raw), repoConfig)
	return repoConfig, err
}
