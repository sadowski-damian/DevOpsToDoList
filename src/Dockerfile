# Build stage from a base image .NET SDK 8.0, it contains compiler and building tools ~ 800MB
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build 
# Setting working directory, next commands will be run in /src directory (if it doesnt exist, Docker creates the directory)
WORKDIR /src

# Copy .csproj file which contains list of dependencies
COPY WentToProd/*.csproj ./WentToProd/
# Download all dependencies defined in .csproj and save it in a container.
RUN dotnet restore WentToProd/*.csproj

# Copy all files, we do that after restore step to not invalidate the restore cache layer.
COPY WentToProd/ ./WentToProd/
# Compile and publish app, -c Release = prod mode with optimization, -o /app/publish = all output files will be stored there
RUN dotnet publish WentToProd/*.csproj -c Release -o /app/publish

# Changing base image to aspnet, only runtime to run the app - without compilator and building tools ~220MB, final image contains only files that we copy
FROM mcr.microsoft.com/dotnet/aspnet:8.0
# Setting another working directory, this is where our app lives
WORKDIR /app

# Copy our compiled application from the build stage (/app/publish) to the current directory (/app), we move only ready artifacts without SDK and source code.
COPY --from=build /app/publish .
# Metadata - it doesnt really open port 8080, it documents that our docker container listens on port 8080
EXPOSE 8080

# Entrypoint for the container, thats the command container runs when starting, it starts app using runtime.
ENTRYPOINT ["dotnet", "WentToProd.dll"] 

