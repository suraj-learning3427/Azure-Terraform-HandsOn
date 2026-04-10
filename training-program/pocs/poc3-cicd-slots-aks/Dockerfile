# Multi-stage Dockerfile: build stage + runtime stage
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files and restore (layer caching optimization)
COPY ["src/MyApp/MyApp.csproj", "src/MyApp/"]
RUN dotnet restore "src/MyApp/MyApp.csproj"

# Copy source and build
COPY . .
WORKDIR "/src/src/MyApp"
RUN dotnet build "MyApp.csproj" -c Release -o /app/build

# Stage 2: Publish
FROM build AS publish
RUN dotnet publish "MyApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Stage 3: Runtime (minimal image — no SDK)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Run as non-root user
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

COPY --from=publish /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
