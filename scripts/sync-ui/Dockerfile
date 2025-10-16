FROM node:18-alpine

# Install pnpm
RUN npm install -g pnpm@8

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy application files
COPY . .

# Expose port
EXPOSE 3456

# Start server
CMD ["pnpm", "start"]
