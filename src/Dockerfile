# Build stage from a base image
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build 
# Current working directory
WORKDIR /src

# Copy .csproj file and then restore
COPY WentToProd/*.csproj ./WentToProd/
RUN dotnet restore WentToProd/*.csproj

# Copy all files and then publish
COPY WentToProd/ ./WentToProd/
RUN dotnet publish WentToProd/*.csproj -c Release -o /app/publish

# Changing base image 
FROM mcr.microsoft.com/dotnet/aspnet:8.0
# And working directory
WORKDIR /app

# Copy application from the build stage
COPY --from=build /app/publish .
# Expose our app on port 8080
EXPOSE 8080

# Entrypoint for the container
ENTRYPOINT ["dotnet", "WentToProd.dll"] 

