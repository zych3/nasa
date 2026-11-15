using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FieldShift.Web.Migrations.FieldData
{
    /// <inheritdoc />
    public partial class ProviderCache : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "provider_cache",
                columns: table => new
                {
                    provider = table.Column<string>(type: "text", nullable: false),
                    key = table.Column<string>(type: "text", nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: true),
                    fetched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_provider_cache", x => new { x.provider, x.key });
                });

            migrationBuilder.CreateIndex(
                name: "IX_provider_cache_expires_at",
                table: "provider_cache",
                column: "expires_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "provider_cache");
        }
    }
}
