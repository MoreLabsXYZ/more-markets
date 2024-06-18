import Link from "next/link";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import styles from "../styles/Home.module.css";
import {
  AppBar,
  Box,
  Button,
  Icon,
  IconButton,
  Toolbar,
  Typography,
} from "@mui/material";

const Header = () => (
  <Box sx={{ flexGrow: 1 }}>
    <AppBar position="static">
      <Toolbar>
        <Box sx={{ flexGrow: 1, display: { xs: "none", md: "flex" } }}>
          <Button href="/" sx={{ my: 2, color: "white", display: "block" }}>
            <Typography variant="h5" component="div" sx={{ flexGrow: 1 }}>
              More Protocol
            </Typography>
          </Button>
        </Box>
        <Box sx={{ flexGrow: 1, display: { xs: "none", md: "flex" } }}>
          <Button href="/" sx={{ my: 2, color: "white", display: "block" }}>
            <Typography component="div" sx={{ flexGrow: 1 }}>
              Markets
            </Typography>
          </Button>
          <Button href="/" sx={{ my: 2, color: "white", display: "block" }}>
            <Typography component="div" sx={{ flexGrow: 1 }}>
              Vaults
            </Typography>
          </Button>
        </Box>
        {/* <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
          <Link href="/">Home</Link>
        </Typography> */}
        <ConnectButton />
      </Toolbar>
    </AppBar>
  </Box>
  // <nav>
  //   <div className="flex flex-row items-center justify-between">
  //     <Link href="/">Home</Link>
  //     <ConnectButton />
  //   </div>
  // </nav>
);

export default Header;
