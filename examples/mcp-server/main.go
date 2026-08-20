package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func main() {
	pool, err := pgxpool.New(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		panic(err)
	}

	s := server.NewMCPServer("craftplan-materials", "0.1.0")

	tool := mcp.NewTool("search_materials",
		mcp.WithDescription("Search the CraftPlan materials catalog by name. Returns sheet size, thickness, price."),
		mcp.WithString("query", mcp.Required(), mcp.Description("Part of the name, e.g. 'plywood' or 'MDF'")),
	)

	s.AddTool(tool, func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		q, _ := req.Params.Arguments["query"].(string)
		rows, err := pool.Query(ctx,
			`SELECT name, thickness, sheet_width, sheet_height, price
			 FROM materials WHERE name ILIKE '%'||$1||'%' LIMIT 20`, q)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		defer rows.Close()

		type mat struct {
			Name           string  `json:"name"`
			Thickness      int     `json:"thickness"`
			SheetW, SheetH int     `json:"sheet_w"`
			Price          float64 `json:"price"`
		}
		var out []mat
		for rows.Next() {
			var m mat
			if err := rows.Scan(&m.Name, &m.Thickness, &m.SheetW, &m.SheetH, &m.Price); err != nil {
				return mcp.NewToolResultError(err.Error()), nil
			}
			out = append(out, m)
		}
		if err := rows.Err(); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		b, _ := json.Marshal(out)
		return mcp.NewToolResultText(string(b)), nil
	})

	if err := server.ServeStdio(s); err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
}
