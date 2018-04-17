package config

import (
	"fmt"
	"github.com/stretchr/testify/suite"
	"io/ioutil"
	"os"
	pathutil "path"
	"testing"
	"time"
	"github.com/urfave/cli"
)

type RepoConfigTestSuite struct {
	suite.Suite
	TempDirectory  string
	TempConfigFile string
}

func (suite *RepoConfigTestSuite) SetupSuite() {
	timestamp := time.Now().Format("20060102150405")
	tempDirectory := fmt.Sprintf("../../.test/chartmuseum-repo-config/%s", timestamp)
	os.MkdirAll(tempDirectory, os.ModePerm)
	suite.TempDirectory = tempDirectory

	tempConfigFile := pathutil.Join(tempDirectory, "chartmuseum.yaml")

	data := []byte(

		`
anonymousget: true

basicauth:
	user: "mydefaultuser"
	pass: "mydefaultpass"

repos:
	org1:
		repo2:
			anonymousget: false
			basicauth:
    			user: "mycustomuser"
    			pass: "mycustompass"
`,
	)

	err := ioutil.WriteFile(tempConfigFile, data, 0644)
	suite.Nil(err, fmt.Sprintf("no error creating new config file %s", tempConfigFile))
	suite.TempConfigFile = tempConfigFile
}

func (suite *RepoConfigTestSuite) TearDownSuite() {
	err := os.RemoveAll(suite.TempDirectory)
	suite.Nil(err, "no error deleting temp directory")
}

func (suite *RepoConfigTestSuite) TestUpdateFromCLIContext() {
	var conf *Config
	var c *cli.Context
	var err error

	// populate config from config file
	conf = NewConfig()
	suite.NotNil(conf)
	c = getNewContext()
	c.Set("config", suite.TempConfigFile)
	err = conf.UpdateFromCLIContext(c)
	fmt.Println(err)
	suite.Nil(err)
	suite.Equal(true, conf.GetBool("anonymousget"))
	suite.Equal("mydefaultuser", conf.GetString("basicauth.user"))
	suite.Equal("mydefaultpass", conf.GetString("basicauth.pass"))

	repoConfig, err := conf.GetRepoConfig("org1/repo2")
	suite.Nil(err)
	suite.Equal(false, repoConfig.AnonymousGet)
}

func TestRepoConfigTestSuite(t *testing.T) {
	suite.Run(t, new(RepoConfigTestSuite))
}
