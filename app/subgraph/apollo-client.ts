import { ApolloClient, InMemoryCache } from "@apollo/client";

const query_url =
  "https://gateway-testnet-arbitrum.network.thegraph.com/api/df4d337693579d28573c83d0eff73522/subgraphs/id/CzhLWMztfP7HBN5Fu4k1ahL6DaVn83V4QaDEipdkEE7L";

const apolloClient = new ApolloClient({
  uri: query_url, // Замените на URL вашего Subgraph
  cache: new InMemoryCache(),
});

export default apolloClient;
