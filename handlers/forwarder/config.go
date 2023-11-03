package forwarder

import (
	"errors"
	"fmt"
	"net/url"

	"github.com/go-logr/logr"
)

var (
	ErrInvalidDestination = errors.New("invalid destination URI")
	ErrMissingS3Client    = errors.New("missing S3 client")
)

type Config struct {
	DestinationURI string // S3 URI to write messages and copy files to
	LogPrefix      string // prefix used when writing SQS messages to S3
	S3Client       S3Client
	Logger         *logr.Logger
	SizeLimit      int64
}

func (c *Config) Validate() error {
	var errs []error
	if c.DestinationURI == "" {
		errs = append(errs, fmt.Errorf("%w: %q", ErrInvalidDestination, c.DestinationURI))
	} else {
		u, err := url.ParseRequestURI(c.DestinationURI)
		switch {
		case err != nil:
			errs = append(errs, fmt.Errorf("%w: %w", ErrInvalidDestination, err))
		case u.Scheme != "s3":
			errs = append(errs, fmt.Errorf("%w: scheme must be \"s3\"", ErrInvalidDestination))
		}
	}

	if c.SizeLimit <= 0 {
		errs = append(errs, fmt.Errorf("SizeLimit must be a positive value, got: %d", c.SizeLimit))
	}

	if c.S3Client == nil {
		errs = append(errs, ErrMissingS3Client)
	}

	return errors.Join(errs...)
}
