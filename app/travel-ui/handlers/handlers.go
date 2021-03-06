// Package handlers contains the full set of handler functions and routes
// supported by the web api.
package handlers

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/dgraph-io/travel/business/data"
	"github.com/dgraph-io/travel/business/mid"
	"github.com/dgraph-io/travel/foundation/web"
	"github.com/pkg/errors"
)

// UI constructs an http.Handler with all application routes defined.
func UI(build string, shutdown chan os.Signal, log *log.Logger, gqlConfig data.GraphQLConfig, browserEndpoint string, mapsKey string) (*web.App, error) {
	app := web.NewApp(shutdown, mid.Logger(log), mid.Errors(log), mid.Metrics(), mid.Panics(log))

	// Register the index page for the website.
	index, err := newIndex(gqlConfig, browserEndpoint, mapsKey)
	if err != nil {
		return nil, errors.Wrap(err, "loading index template")
	}
	app.Handle(http.MethodGet, "/", index.handler)

	// Register the assets.
	fs := http.FileServer(http.Dir("assets"))
	fs = http.StripPrefix("/assets/", fs)
	f := func(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
		fs.ServeHTTP(w, r)
		return nil
	}
	app.Handle(http.MethodGet, "/assets/*", f)

	// Register health check endpoint.
	check := check{
		build:     build,
		gqlConfig: gqlConfig,
	}
	app.Handle(http.MethodGet, "/health", check.health)

	// Register data load endpoint.
	fetch := fetch{
		gqlConfig: gqlConfig,
	}
	app.Handle(http.MethodGet, "/data/:city", fetch.data)

	return app, nil
}
