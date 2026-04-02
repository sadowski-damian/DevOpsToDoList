# Build stage from a base image
FROM mcr.microsoft.com/dotnet/sdk:8.0
# Current working directory
WORKDIR /src

# Copy .csproj file and then restore
COPY ToDoApi/*.csproj ./ToDoApi/
RUN dotnet restore ToDoApi/*.csproj

# Copy all files and then publish
COPY ToDoApi/ ./ToDoApi/
RUN dotnet publish ToDoApi/*.csproj -c Release -o /app/publish

# Changing base image 
FROM mcr.microsoft.com/dotnet/aspnet:8.0
