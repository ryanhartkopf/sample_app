# Use official latest node.js 8.x.x
FROM node:8.9.1

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm install

# Copy app source
COPY . .

# Expose endpoint
EXPOSE 8080

# Start service
CMD [ "npm", "start" ]
