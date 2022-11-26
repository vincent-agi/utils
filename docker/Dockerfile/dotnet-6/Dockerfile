FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
COPY ["./scripts/entrypoint.sh", "/app"]
EXPOSE 80
RUN mkdir Ressources

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["fcs-backend.csproj", "./"]
RUN dotnet restore "fcs-backend.csproj"
COPY . .
WORKDIR "/src/"
RUN dotnet build "fcs-backend.csproj" --no-self-contained --runtime  debian.11-x64 -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "fcs-backend.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT [ "dotnet", "fcs-backend.dll" ]
