using Microsoft.EntityFrameworkCore;
using Usuarios.Adapters.Persistence;
using Usuarios.Domain.Entities;
using Usuarios.Domain.Ports;

namespace Usuarios.Adapters.Repositories;

public sealed class SqlUserRepository(UsersDbContext dbContext) : IUserRepository
{
    public User Save(User user)
    {
        if (dbContext.Users.Any(item => item.Id == user.Id))
        {
            dbContext.Users.Update(user);
        }
        else
        {
            dbContext.Users.Add(user);
        }

        dbContext.SaveChanges();
        return user;
    }

    public IReadOnlyList<User> ListAll() => dbContext.Users
        .AsNoTracking()
        .OrderBy(item => item.Id)
        .ToArray();

    public User? GetById(int userId) => dbContext.Users
        .AsNoTracking()
        .SingleOrDefault(item => item.Id == userId);

    public void Delete(int userId) => dbContext.Users
        .Where(item => item.Id == userId)
        .ExecuteDelete();
}
