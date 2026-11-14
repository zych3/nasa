using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace FieldShift.Web.Migrations
{
    /// <inheritdoc />
    public partial class InitialPrices : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "price_sources",
                columns: table => new
                {
                    id = table.Column<string>(type: "text", nullable: false),
                    country = table.Column<string>(type: "char(2)", nullable: false),
                    last_attempt_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_success_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_error = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_price_sources", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "price_series",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    source_id = table.Column<string>(type: "text", nullable: false),
                    crop_id = table.Column<string>(type: "text", nullable: false),
                    frequency = table.Column<string>(type: "text", nullable: false),
                    currency = table.Column<string>(type: "char(3)", nullable: false),
                    unit = table.Column<string>(type: "text", nullable: false),
                    source_name = table.Column<string>(type: "text", nullable: false),
                    note_code = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_price_series", x => x.id);
                    table.CheckConstraint("ck_price_series_frequency", "frequency IN ('weekly', 'monthly', 'yearly')");
                    table.ForeignKey(
                        name: "FK_price_series_price_sources_source_id",
                        column: x => x.source_id,
                        principalTable: "price_sources",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "price_points",
                columns: table => new
                {
                    series_id = table.Column<int>(type: "integer", nullable: false),
                    period_start = table.Column<DateOnly>(type: "date", nullable: false),
                    price = table.Column<decimal>(type: "numeric(12,2)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_price_points", x => new { x.series_id, x.period_start });
                    table.ForeignKey(
                        name: "FK_price_points_price_series_series_id",
                        column: x => x.series_id,
                        principalTable: "price_series",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_price_series_crop_id",
                table: "price_series",
                column: "crop_id");

            migrationBuilder.CreateIndex(
                name: "IX_price_series_source_id_crop_id",
                table: "price_series",
                columns: new[] { "source_id", "crop_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "price_points");

            migrationBuilder.DropTable(
                name: "price_series");

            migrationBuilder.DropTable(
                name: "price_sources");
        }
    }
}
