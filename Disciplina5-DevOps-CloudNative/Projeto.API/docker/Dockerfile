# Veja https://aka.ms/customizecontainer para saber como personalizar seu contêiner de depuração e como o Visual Studio usa este Dockerfile para construir suas imagens para depuração mais rápida.

# Esta etapa é usada ao executar o programa no modo rápido a partir do Visual Studio (padrão para configuração de depuração).
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
ENV ASPNETCORE_HTTP_PORTS=8080
USER $APP_UID
WORKDIR /app
EXPOSE 8080


# Esta etapa é usada para compilar o projeto de serviço
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["src/Usuarios.Api/Usuarios.Api.csproj", "src/Usuarios.Api/"]
COPY ["src/Usuarios.Adapters/Usuarios.Adapters.csproj", "src/Usuarios.Adapters/"]
COPY ["src/Usuarios.Application/Usuarios.Application.csproj", "src/Usuarios.Application/"]
COPY ["src/Usuarios.Domain/Usuarios.Domain.csproj", "src/Usuarios.Domain/"]
RUN dotnet restore "./src/Usuarios.Api/Usuarios.Api.csproj"
COPY . .
WORKDIR "/src/src/Usuarios.Api"
RUN dotnet build "./Usuarios.Api.csproj" -c $BUILD_CONFIGURATION -o /app/build

# Esta etapa é usada para publicar o projeto de serviço a ser copiado para a etapa final.
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./Usuarios.Api.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# Esta etapa é usada em produção ou ao executar a partir do VS no modo normal (padrão quando a configuração de depuração não está sendo usada).
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Usuarios.Api.dll"]
