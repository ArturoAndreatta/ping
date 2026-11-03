// Gera o par VAPID (uma vez só). A pública vai no app (app/lib/push.dart) e no wrangler.toml; a privada fica
// em ~/.ping/vapid.json (fora do repositório) e vira o segredo VAPID_PRIVADA do Worker.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { gerarVapid } from "../src/webpush.js";

const pasta = path.join(os.homedir(), ".ping");
const arq = path.join(pasta, "vapid.json");
if (fs.existsSync(arq) && !process.argv.includes("--trocar")) {
  console.log(`Já existe: ${arq} (use --trocar pra gerar outro; todos os aparelhos teriam que se inscrever de novo)`);
  console.log("Pública:", JSON.parse(fs.readFileSync(arq, "utf8")).publica);
  process.exit(0);
}
const par = await gerarVapid();
fs.mkdirSync(pasta, { recursive: true });
fs.writeFileSync(arq, JSON.stringify(par, null, 2));
console.log(`Gravado em ${arq}`);
console.log("Pública:", par.publica);
