<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="utf-8"%>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="sql" uri="jakarta.tags.sql" %>
<%@ taglib prefix="fmt" uri="jakarta.tags.fmt" %>
<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
<fmt:requestEncoding value="utf-8" />

<sql:setDataSource var="dataSource" driver="org.h2.Driver" url="jdbc:h2:sdev" />

<%-- 在庫追加処理 --%>
<c:if test="${param.addStock != null}">
  <sql:update dataSource="${dataSource}">
    UPDATE TORI_STOCKS SET STOCK = STOCK + 50 WHERE PRODUCT_ID = ?
    <sql:param value="${param.addStock}" />
  </sql:update>
</c:if>

<%-- 注文確定処理 --%>
<c:if test="${param.action eq 'order'}">
  <c:set var="momo" value="${param.momoCount}" />
  <c:set var="kawa" value="${param.kawaCount}" />
  <c:set var="negima" value="${param.negimaCount}" />
  <c:set var="ticket" value="${param.ticketNo}" />

  <c:set var="total" value="${momo + kawa + negima}" />
  <c:set var="price" value="${(total div 5) * 600 + (total mod 5) * 150}" />

  <sql:update dataSource="${dataSource}">
    INSERT INTO TORI_LOGS(LOG_TIME, MOMO_COUNT, KAWA_COUNT, NEGIMA_COUNT, TOTAL_COUNT, PRICE, TICKET_NO)
    VALUES (CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?)
    <sql:param value="${momo}" />
    <sql:param value="${kawa}" />
    <sql:param value="${negima}" />
    <sql:param value="${total}" />
    <sql:param value="${price}" />
    <sql:param value="${ticket}" />
  </sql:update>

  <sql:update dataSource="${dataSource}">
    INSERT INTO TORI_ORDERS(ticket_number, momo, kawa, negima, status)
    VALUES (?, ?, ?, ?, 'pending')
    <sql:param value="${ticket}" />
    <sql:param value="${momo}" />
    <sql:param value="${kawa}" />
    <sql:param value="${negima}" />
  </sql:update>


  <sql:update dataSource="${dataSource}">
    UPDATE TORI_STOCKS SET STOCK = STOCK - ? WHERE PRODUCT_ID = 1
    <sql:param value="${param.momoCount}" />
  </sql:update>
  <sql:update dataSource="${dataSource}">
    UPDATE TORI_STOCKS SET STOCK = STOCK - ? WHERE PRODUCT_ID = 2
    <sql:param value="${param.kawaCount}" />
  </sql:update>
  <sql:update dataSource="${dataSource}">
    UPDATE TORI_STOCKS SET STOCK = STOCK - ? WHERE PRODUCT_ID = 3
    <sql:param value="${param.negimaCount}" />
  </sql:update>
</c:if>

<%-- 在庫リセット処理 --%>
<c:if test="${param.resetStock != null}">
  <sql:update dataSource="${dataSource}">
    UPDATE TORI_STOCKS SET STOCK = 0 WHERE PRODUCT_ID = ?
    <sql:param value="${param.resetStock}" />
  </sql:update>
</c:if>

<%-- 済ボタン処理 --%>
<c:if test="${param.doneOrder != null}">
  <sql:update dataSource="${dataSource}">
    UPDATE TORI_ORDERS SET status='done' WHERE order_id=?
    <sql:param value="${param.doneOrder}" />
  </sql:update>
</c:if>

<%-- ログ削除処理 --%>
<sql:query var="ordersData" dataSource="${dataSource}">
  SELECT * FROM TORI_ORDERS WHERE status='pending' ORDER BY order_id
</sql:query>


<%-- データの取得 --%>
<sql:query var="stocksData" dataSource="${dataSource}">
  SELECT P.PRODUCT_ID, P.NAME, P.PRICE, S.STOCK
  FROM TORI_PRODUCTS P JOIN TORI_STOCKS S ON P.PRODUCT_ID = S.PRODUCT_ID
</sql:query>

<sql:query var="logsData" dataSource="${dataSource}">
  SELECT * FROM TORI_LOGS ORDER BY LOG_ID DESC
</sql:query>


<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>焼き鳥レジシステム</title>
    <link rel="stylesheet" href="test5.css">
</head>
<body>
<div class="container">
    <!-- 左側：会計 + 在庫 -->
    <div class="left">
        <!-- 会計 -->
        <div class="top">
            <h2>会計</h2>
            <form method="post">
                <input type="hidden" name="action" value="order">
                <div class="product">
                    <label>もも:　　　　　　　　</label>
                    <button type="button" onclick="changeQty('momo', -1)">－</button>
                    <input type="number" id="momo" name="momoCount" value="0" min="0" readonly>
                    <button type="button" onclick="changeQty('momo', 1)">＋</button>
                </div>
                <div class="product">
                    <label>かわ:　　　　　　　　</label>
                    <button type="button" onclick="changeQty('kawa', -1)">－</button>
                    <input type="number" id="kawa" name="kawaCount" value="0" min="0" readonly>
                    <button type="button" onclick="changeQty('kawa', 1)">＋</button>
                </div>
                <div class="product">
                    <label>ねぎま:　　　　　　　　</label>
                    <button type="button" onclick="changeQty('negima', -1)">－</button>
                    <input type="number" id="negima" name="negimaCount" value="0" min="0" readonly>
                    <button type="button" onclick="changeQty('negima', 1)">＋</button>
                </div>
                <div>
                    合計: <span id="total">0</span> 円
                　　　　　　整理券番号: <input type="text" name="ticketNo" required>
                </div>
                <div>　　　　　　　　　　　　　　　
                <button class="order-btn" type="submit">注文確定</button>
                </div>
            </form>
        </div>

        <!-- 在庫 -->
        <div class="bottom">
            <h2>在庫</h2>
            <table>
                <thead>
                <tr><th>商品</th><th>残数</th><th>操作</th></tr>
                </thead>
                <tbody>
                <c:forEach var="row" items="${stocksData.rows}">
                <tr>
                <td>${row.NAME}</td>
                <td class="stock-value">${row.STOCK}</td>
                <td>
                    <form method="post" style="display:inline;">
                        <input type="hidden" name="addStock" value="${row.PRODUCT_ID}">
                        <button class="stock-btn plus" type="submit">＋50</button>
                    </form>
                    <form method="post" style="display:inline;">
                        <input type="hidden" name="resetStock" value="${row.PRODUCT_ID}">
                        <button class="stock-btn reset" type="submit">0にする</button>
                    </form>
                </td>
                </tr>
                </c:forEach>
                </tbody>
            </table>
        </div>
    </div>

    <!-- 右側：受け渡し -->
    <div class="right">
        <h2>受け渡し</h2>
        <table id="orders">
            <thead>
            <tr><th>整理券</th><th>もも</th><th>かわ</th><th>ねぎま</th><th>操作</th></tr>
            </thead>
            <tbody>
            <c:forEach var="ord" items="${ordersData.rows}">
            <tr>
                <td>${ord.TICKET_NUMBER}</td>
                <td>${ord.MOMO}</td>
                <td>${ord.KAWA}</td>
                <td>${ord.NEGIMA}</td>
                <td>
                    <form method="post" style="display:inline">
                        <input type="hidden" name="doneOrder" value="${ord.ORDER_ID}">
                        <button type="submit" class="done-btn" onclick="markDone(this)">済</button>
                    </form>
                </td>
            </tr>
            </c:forEach>
            </tbody>
        </table>
    </div>

</div>

<script>
// 数量管理
const qty = { momo: 0, kawa: 0, negima: 0 };

// 数量変更処理
function changeQty(item, delta) {
    qty[item] = Math.max(0, qty[item] + delta);
    document.getElementById(item).value = qty[item];
    updateTotal();
}

// 合計更新
function updateTotal() {
    let count = qty.momo + qty.kawa + qty.negima;
    let sets = Math.floor(count / 5);
    let remainder = count % 5;
    let total = sets * 600 + remainder * 150;
    document.getElementById("total").textContent = total;
}

// ＋50
function addStock(button, amount) {
    const row = button.closest("tr");
    const stockCell = row.querySelector(".stock-value");
    let currentStock = parseInt(stockCell.textContent, 10);
    stockCell.textContent = currentStock + amount;
}

// 0にする
function resetStock(button) {
    const row = button.closest("tr");
    const stockCell = row.querySelector(".stock-value");
    stockCell.textContent = 0;
}

// 済ボタン処理
function markDone(button) {
    const row = button.closest("tr");
    row.style.display = "none";
}

</script>
</body>
</html>
