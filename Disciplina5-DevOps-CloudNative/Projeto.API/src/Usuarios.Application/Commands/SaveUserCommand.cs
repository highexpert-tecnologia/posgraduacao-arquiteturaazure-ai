namespace Usuarios.Application.Commands;

public sealed record SaveUserCommand(
    string Nome,
    DateOnly DtNascimento,
    bool Status,
    IReadOnlyList<string> Telefones);
