// Use only the project's publishable key here.
const config = {url:"", publishableKey:""};
const gate = document.getElementById("portalGate");
const shell = document.querySelector(".shell");
const message = document.getElementById("portalAuthStatus");
const form = document.getElementById("portalAuthForm");
const pending = document.getElementById("portalPending");
const leadership = document.getElementById("portalLeadership");
const assignments = document.getElementById("portalAssignments");
const accountControls = document.getElementById("portalAccountControls");
const roles = {employee:"Сотрудник", deputy:"Заместитель комиссара", commissioner:"Комиссар"};
const redirectTo = new URL(location.pathname, location.origin).href;
let client;
let stateVersion = 0;

async function showAccount(session){
 const version = ++stateVersion;
 shell.hidden = true;
 gate.hidden = false;
 leadership.hidden = true;
 assignments.replaceChildren();
 accountControls.hidden = !session;
 form.hidden = Boolean(session);
 pending.hidden = true;
 message.textContent = "";
 if (!session) return;
 const {data, error} = await client.from("portal_accounts").select("role")
  .eq("user_id",session.user.id).single();
 if (version !== stateVersion) return;
 if (error) {
  message.textContent = "Не удалось загрузить аккаунт. Обнови страницу или войди снова.";
  return;
 }
 if (!Object.hasOwn(roles, data.role)) {
  pending.hidden = false;
  return;
 }
 shell.hidden = false;
 gate.hidden = true;
 document.getElementById("roleLabel").textContent = roles[data.role];
 const canAssign = data.role === "commissioner" || data.role === "deputy";
 document.getElementById("portalOpenLeadership").hidden = !canAssign;
}

async function showAssignments(){
 const version = stateVersion;
 leadership.hidden = false;
 assignments.textContent = "Загрузка…";
 const {data, error} = await client.from("portal_accounts").select("user_id,email").is("role",null);
 if (version !== stateVersion) return;
 assignments.replaceChildren();
 if (error || !data.length) {
  assignments.textContent = error ? "Не удалось загрузить заявки." : "Нет аккаунтов без роли.";
  return;
 }
 for (const account of data) {
  const row = document.createElement("div");
  const label = document.createElement("span");
  label.textContent = account.email || account.user_id;
  row.append(label);
  const commissioner = document.getElementById("roleLabel").textContent === roles.commissioner;
  for (const role of commissioner ? ["employee","deputy"] : ["employee"]) {
   const button = document.createElement("button");
   button.type = "button";
   button.className = "action secondary";
   button.textContent = roles[role];
   button.addEventListener("click", async () => {
    row.querySelectorAll("button").forEach((control) => { control.disabled = true; });
    const {error} = await client.rpc("portal_assign_role",{target_user:account.user_id,target_role:role});
    if (version !== stateVersion) return;
    if (error) {
     label.textContent = (account.email || account.user_id) + " · Назначение недоступно. Проверь, подтверждён ли аккаунт.";
     row.querySelectorAll("button").forEach((control) => { control.disabled = false; });
     return;
    }
    await showAssignments();
   });
   row.append(button);
  }
  assignments.append(row);
 }
}

async function signOut(){
 const {error} = await client.auth.signOut();
 if (error) (shell.hidden ? message : document.getElementById("portalSessionStatus")).textContent = "Не удалось выйти. Попробуй ещё раз.";
}

async function init(){
 if (!config.url || !config.publishableKey) {
  message.textContent = "Регистрация ещё не подключена.";
  return;
 }
 try {
  const {createClient} = await import("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm");
  client = createClient(config.url,config.publishableKey);
  const {data,error} = await client.auth.getSession();
  if (error) throw error;
  await showAccount(data.session);
  client.auth.onAuthStateChange((event, session) => {
   if (event === "SIGNED_IN" || event === "SIGNED_OUT" || event === "USER_UPDATED") {
    setTimeout(() => showAccount(session),0);
   }
  });
 } catch {
  message.textContent = "Не удалось подключиться к регистрации.";
  return;
 }

 form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const email = form.elements.email.value.trim();
  const password = form.elements.password.value;
  const register = event.submitter?.value === "register";
  const {data,error} = register
   ? await client.auth.signUp({email,password,options:{emailRedirectTo:redirectTo}})
   : await client.auth.signInWithPassword({email,password});
  if (error) {
   message.textContent = register ? "Не удалось зарегистрироваться. Проверь адрес и пароль." : "Не удалось войти. Проверь почту, пароль и подтверждение аккаунта.";
  } else if (data.session) {
   await showAccount(data.session);
  } else {
   message.textContent = "Проверь почту и подтверди регистрацию по ссылке.";
  }
 });
 document.getElementById("portalDiscord").addEventListener("click",async () => {
  const {error} = await client.auth.signInWithOAuth({provider:"discord",options:{redirectTo}});
  if (error) message.textContent = "Не удалось открыть вход через Discord.";
 });
 document.querySelectorAll("[data-portal-signout]").forEach((button) => button.addEventListener("click", signOut));
 document.getElementById("portalOpenLeadership").addEventListener("click", showAssignments);
 document.getElementById("portalCloseLeadership").addEventListener("click", () => { leadership.hidden = true; });
}
init();
