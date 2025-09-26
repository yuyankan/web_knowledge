
# 会话总结：FastAPI 图片访问 & Power BI & HTTPS 证书

**日期**: 2025-09-26 13:16:40

---

## 1. Power BI 图片加载问题

- **问题**:  
  - FastAPI 代理图片（BMP 转 JPG/PNG），浏览器可以显示，但 Power BI Desktop 显示裂开标识。  
  - Power BI Service 在线版可以显示公共 HTTPS 图片，但无法显示自建 HTTP / BMP 图片。

- **原因分析**:  
  1. Power BI **不支持 BMP 格式**，需转换为 PNG/JPEG。  
  2. Power BI Service **要求 HTTPS + 公网域名**，IP 地址或 HTTP 不被支持。  
  3. Power BI Desktop 在本地测试时，加载外链图片有限制，刷新时可能短暂闪现，但最终失败。  
  4. Base64 图片虽然能显示，但体积大（图片内容直接嵌入表格字段中）。  

- **结论**:  
  - 必须将图片转换为 JPG/PNG。  
  - 需要通过 HTTPS 公网域名访问，且证书必须是受信任 CA 签发。  
  - Power BI Service 渲染图片时，IP 或 HTTP 链接会失败。  

---

## 2. FastAPI/Nginx 图片服务优化

### 核心优化点
- 缓存：避免重复转换 BMP → JPG，减少 CPU 消耗。  
- 异步 IO：使用 `run_in_threadpool` 提高响应性能。  
- 返回格式：统一为 `image/jpeg` 或 `image/png`。  

### URL 设计
- 原始 BMP 文件：`file.BMP`  
- 转换访问地址：`/images/file.BMP.jpg`  
- 实际缓存 key = `file.BMP.jpg`（逻辑上是 BMP → JPG 转换）。  

### Power BI 限制
- 即使路由设计成 `.BMP.jpg`，Power BI Service **依旧要求 HTTPS 域名**。  

---

## 3. HTTPS 证书问题

### 要点
- **HTTP 与 HTTPS 区别**：HTTPS 提供加密和身份验证，Power BI Service 要求 HTTPS。  
- **证书来源**：  
  - 公网环境推荐使用 Let’s Encrypt（免费）或公司 CA。  
  - 自签证书只能在内部测试，Power BI Service 不支持。  

### 如何确认服务器是否有证书
1. **浏览器检查**  
   - 访问 `https://server2ip/` 或 `https://domain/`  
   - 点击 🔒 查看证书信息（Issuer, 有效期, 绑定域名）。  

2. **命令行检查**  
   ```bash
   curl -vk https://SERVER2_IP/
   openssl s_client -connect SERVER2_IP:443
   ```
   - 如果有证书，输出会包含证书链和 Issuer 信息。  
   - 如果没有，连接失败或显示自签证书。  

3. **服务器配置检查**  
   ```bash
   grep -r "ssl_certificate" /etc/nginx/conf.d/
   ```
   - 确认是否有 `ssl_certificate` 和 `ssl_certificate_key` 配置。  
   - 查看证书文件：  
     ```bash
     openssl x509 -in /path/to/cert.crt -text -noout
     ```

### 注意事项
- 公有 CA 证书绑定 **域名**，不是 IP → `https://ip/` 无法通过校验。  
- 必须让 Power BI Service 能从公网访问该域名。  

---

## 4. 总结

- **Power BI Desktop** → 不能稳定显示外部图片，特别是 HTTP/IP 地址。  
- **Power BI Service** → 只支持 HTTPS + 域名 + 公有证书。  
- **解决方案**：  
  1. 使用 FastAPI 将 BMP 转 JPG/PNG 并缓存。  
  2. 在 Nginx 上启用 HTTPS，绑定公司域名。  
  3. 使用 Let’s Encrypt 或公司 CA 签发的证书。  
  4. 在 Power BI 中使用 HTTPS 域名地址（如 `https://images.company.com/file.jpg`）。  

---
# 本次谈话总结

## 1. 容器端口与宿主机端口
- 容器运行时需要将容器端口映射到宿主机端口。
- 宿主机端口对外暴露时可以是 HTTP，也可以是 HTTPS。
- HTTPS 需要在宿主机或代理层配置证书。

---

## 2. 端口 443 的作用
- 默认用于 HTTPS（加密的 HTTP）服务。
- 浏览器或客户端访问 HTTPS 网站时，默认使用端口 443。
- 一般服务器会对外只开放 443 端口，内部再通过反向代理转发到 FastAPI、其他服务端口。

---

## 3. 证书管理
- **证书作用**：加密数据传输、验证服务器身份、保证数据完整性。
- **获取方式**：
  - 公网服务：通常通过 CA 签发（如 Let's Encrypt 免费证书）。
  - 内网服务：可用自签名证书，或公司内部 CA 签发。
- **是否唯一**：
  - 每台服务器可以有单独证书。
  - 也可以多个服务器共用一个泛域名证书。
- **更新周期**：
  - 公共 CA 证书：3 个月（Let's Encrypt）或 1 年。
  - 自签名证书：一般 1~3 年，需手动更新。

---

## 4. Power BI 与图片加载
- Power BI Service 不允许加载 **HTTP 图片**，只允许 HTTPS，原因是浏览器安全限制（Mixed Content）。
- Gateway 的作用是作为桥梁安全访问内网数据源，但本身不具备路径级别的 URL 重写能力。
- 解决办法：
  - 使用代理（Nginx/Apache/FastAPI）来转发和映射 HTTP → HTTPS。
  - 在内网服务器上部署 HTTPS（可用自签名证书）。
  - Power BI 中填入虚拟的 HTTPS URL，Gateway 转发到内网 HTTP。

---

## 5. Mixed Content
- **定义**：在 HTTPS 页面中加载 HTTP 内容（如图片、脚本、iframe）。
- **风险**：HTTP 内容可能被窃取或篡改，破坏页面安全。
- **结果**：浏览器会阻止加载 HTTP 资源，必须使用 HTTPS。

---

## 6. Base64 与图片
- Base64 原理：用 64 个可打印字符表示二进制数据。
- 每 3 字节（24bit）数据被拆分成 4 组，每组 6bit，对应一个 Base64 字符（8bit）。
- 因此体积会 **增大约 33%**。
- 作用：可以将图片等二进制嵌入 HTML 文本中，而不是通过 URL 引用。

---

## 7. 内网 HTTPS 部署
- 内部 HTTPS 可以使用 **自签名证书**。
- 自签名证书风险很低，尤其在只为了解决 Power BI Mixed Content 问题时。
- 客户端需要手动信任自签名证书，或者公司内部 CA 统一签发并分发信任。

---

## 8. 公钥与私钥
- **公钥（Public Key）**：公开，用于加密数据或验证签名。
- **私钥（Private Key）**：保密，只在服务器端保存，用于解密数据或生成签名。
- HTTPS 流程：
  1. 服务器将公钥通过证书发给客户端。
  2. 客户端生成会话密钥，用公钥加密发送。
  3. 服务器用私钥解密得到会话密钥。
  4. 后续通信使用对称加密（更高效）。
- 作用总结：**公钥加密/验证，私钥解密/签名**。

---

## 9. 总体结论
- HTTPS 的本质是 **加密通信和身份验证**，与是否外网无关。
- Power BI Mixed Content 问题需要 HTTPS URL，即使内部服务也可以用自签名证书解决。
- Gateway 不能做精确 URL 重写，建议配合代理或 API 实现。
- 内网使用自签名证书风险可控，完全能满足 Power BI 的需要。
