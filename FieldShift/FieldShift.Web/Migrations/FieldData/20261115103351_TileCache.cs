using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FieldShift.Web.Migrations.FieldData
{
    /// <inheritdoc />
    public partial class TileCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "tile_cache",
                columns: table => new
                {
                    layer = table.Column<string>(type: "text", nullable: false),
                    z = table.Column<int>(type: "integer", nullable: false),
                    x = table.Column<int>(type: "integer", nullable: false),
                    y = table.Column<int>(type: "integer", nullable: false),
                    png = table.Column<byte[]>(type: "bytea", nullable: false),
                    fetched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tile_cache", x => new { x.layer, x.z, x.x, x.y });
                });

            migrationBuilder.CreateIndex(
                name: "IX_tile_cache_expires_at",
                table: "tile_cache",
                column: "expires_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "tile_cache");
        }
    }
}
