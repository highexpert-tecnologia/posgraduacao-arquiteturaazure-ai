using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System.Text.Json;
using Usuarios.Domain.Entities;

namespace Usuarios.Adapters.Persistence;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users");

        builder.HasKey(item => item.Id);

        builder.Property(item => item.Id).ValueGeneratedOnAdd();

        builder.Property(item => item.Nome).HasMaxLength(200).IsRequired();

        builder.Property(item => item.DtNascimento).HasColumnType("date");

        builder.Property(item => item.Telefones)
            .HasColumnType("nvarchar(max)")
            .HasConversion(
                phones => JsonSerializer.Serialize(phones, JsonSerializerOptions.Default),
                json => JsonSerializer.Deserialize<string[]>(json, JsonSerializerOptions.Default) ?? Array.Empty<string>());

        builder.Property(item => item.Telefones).Metadata.SetValueComparer(
            new ValueComparer<IReadOnlyList<string>>(
                (left, right) => ReferenceEquals(left, right) ||
                    (left != null && right != null && left.SequenceEqual(right)),
                phones => phones == null
                    ? 0
                    : phones.Aggregate(0, (hash, phone) => HashCode.Combine(hash, phone.GetHashCode())),
                phones => phones == null ? Array.Empty<string>() : phones.ToArray()));
    }
}
