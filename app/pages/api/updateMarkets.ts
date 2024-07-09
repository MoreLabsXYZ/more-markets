import type { NextApiRequest, NextApiResponse } from "next";
import { Project, ScriptTarget, VariableDeclarationKind, ts } from "ts-morph";
import path from "path";
import { markets, chainConfig } from "../../config/markets";

type Data = {
  message: string;
};

const filePath = path.join(process.cwd(), "./config/markets.ts");

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<Data>
) {
  if (req.method === "POST") {
    const { name, value, chainId } = req.body;

    console.log("filePath: ", filePath);
    console.log("name: ", name);
    console.log("value: ", value);
    console.log("chainId: ", chainId);
    const project = new Project({
      tsConfigFilePath: path.join(process.cwd(), "tsconfig.json"),
    });
    console.log("project: ", project);

    const sourceFile = project.addSourceFileAtPath(filePath);

    console.log("markets: ", markets);

    // markets[chainId].push({ name: "some name", address: "some address" });
    // console.log("markets: ", markets);

    // Проверяем, существует ли константа
    let variableDeclaration = sourceFile.getVariableDeclaration(name);

    if (variableDeclaration) {
      const initializer = variableDeclaration.getInitializer();
      if (
        initializer &&
        initializer.getKind() === ts.SyntaxKind.ObjectLiteralExpression
      ) {
        const objectLiteral = initializer.asKindOrThrow(
          ts.SyntaxKind.ObjectLiteralExpression
        );
        console.log(chainId.toString());
        const property = objectLiteral.getProperty(chainId.toString());
        console.log(property);
        const address: string = "some address";
        if (
          property &&
          property.getKind() === ts.SyntaxKind.PropertyAssignment
        ) {
          const propertyAssignment = property.asKindOrThrow(
            ts.SyntaxKind.PropertyAssignment
          );
          const arrayInitializer = propertyAssignment.getInitializer();
          if (
            arrayInitializer &&
            arrayInitializer.getKind() === ts.SyntaxKind.ArrayLiteralExpression
          ) {
            const arrayLiteral = arrayInitializer.asKindOrThrow(
              ts.SyntaxKind.ArrayLiteralExpression
            );
            arrayLiteral.addElement(
              `{ name: '${name}', address: '${address}' }`
            );
          }
        } else {
          // Если свойства не существует, создадим его
          objectLiteral.addPropertyAssignment({
            name: chainId.toString(),
            initializer: `[{ name: '${name}', address: '${address}' }]`,
          });
        }
      }
    } else {
      res.status(404).json({ message: "Constant not found" });
      return;
    }

    variableDeclaration = sourceFile.getVariableDeclaration("chainConfig");

    if (variableDeclaration) {
      const initializer = variableDeclaration.getInitializer();
      if (
        initializer &&
        initializer.getKind() === ts.SyntaxKind.ObjectLiteralExpression
      ) {
        const objectLiteral = initializer.asKindOrThrow(
          ts.SyntaxKind.ObjectLiteralExpression
        );
        console.log(chainId.toString());
        const property = objectLiteral.getProperty(chainId.toString());
        console.log(property);
        if (
          property &&
          property.getKind() === ts.SyntaxKind.PropertyAssignment
        ) {
          console.log("hehe");
          const propertyAssignment = property.asKindOrThrow(
            ts.SyntaxKind.PropertyAssignment
          );
          const arrayInitializer = propertyAssignment.getInitializer();
          console.log(arrayInitializer);
          if (
            arrayInitializer &&
            arrayInitializer.getKind() === ts.SyntaxKind.ArrayLiteralExpression
          ) {
            console.log("hehe");
            const arrayLiteral = arrayInitializer.asKindOrThrow(
              ts.SyntaxKind.ArrayLiteralExpression
            );
            arrayLiteral.addElement(
              `{ 
                loanToken: '${value.loanToken}', 
                collateralToken: '${value.collateralToken}, 
                oracle: '${value.oracle},
                irm: '${value.irm},
                lltv: '${value.lltv},' 
                }`
            );
          }
        } else {
          // Если свойства не существует, создадим его
          objectLiteral.addPropertyAssignment({
            name: `"newMarketId"`,
            initializer: `{ 
                loanToken: "${value.loanToken}", 
                collateralToken: "${value.collateralToken}", 
                oracle: "${value.oracle}",
                irm: "${value.irm}",
                lltv: ${value.lltv}, 
                }`,
          });
        }
      }
    } else {
      res.status(404).json({ message: "Constant not found" });
      return;
    }

    await sourceFile.save();

    res.status(200).json({ message: "File updated successfully" });
  } else {
    res.status(405).json({ message: "Method not allowed" });
  }
}
