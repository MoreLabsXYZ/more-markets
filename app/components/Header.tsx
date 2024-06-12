import Link from "next/link";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import styles from "../styles/Home.module.css";

const Header = () => (
  <nav>
    <div className="flex flex-row items-center justify-between">
      <Link href="/">Home</Link>
      <ConnectButton />
    </div>
  </nav>
);

export default Header;
