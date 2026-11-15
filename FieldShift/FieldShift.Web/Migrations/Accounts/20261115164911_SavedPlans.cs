using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FieldShift.Web.Migrations.Accounts
{
    /// <inheritdoc />
    public partial class SavedPlans : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "saved_plans",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    parcel_id = table.Column<string>(type: "text", nullable: true),
                    lat = table.Column<double>(type: "double precision", nullable: false),
                    lon = table.Column<double>(type: "double precision", nullable: false),
                    goal = table.Column<string>(type: "text", nullable: false),
                    plan = table.Column<string>(type: "jsonb", nullable: false),
                    answers = table.Column<string>(type: "jsonb", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_saved_plans", x => x.id);
                    table.ForeignKey(
                        name: "FK_saved_plans_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_saved_plans_user_id_created_at",
                table: "saved_plans",
                columns: new[] { "user_id", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "saved_plans");
        }
    }
}
