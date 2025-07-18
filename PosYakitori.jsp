<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="utf-8"%>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%@ taglib prefix="sql" uri="jakarta.tags.sql" %>
<%@ taglib prefix="fmt" uri="jakarta.tags.fmt" %>
<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>
<fmt:requestEncoding value="utf-8" />

<sql:setDataSource var="dataSource" driver="org.h2.Driver" url="jdbc:h2:sdev" />

<%-- 在庫追加処理 --%>
<c:if test="${param.addStock == 'true'}">
    <sql:update dataSource="${dataSource}">
        UPDATE tori_stock SET stock = stock + 200 WHERE product_id = ?
    <sql:param value="${param.productId}" />
    </sql:update>
    <c:redirect url="index.jsp?screen=stock" />
</c:if>

<%-- 注文受け渡し処理 --%>
<c:if test="${param.completeOrder == 'true'}">
    <sql:update dataSource="${dataSource}">
        UPDATE tori_orders SET status = 'completed' WHERE order_id = ?
    <sql:param value="${param.orderId}" />
    </sql:update>
    <c:redirect url="index.jsp?screen=delivery" />
</c:if>

<%-- 注文確定処理 --%>
<c:if test="${param.submitOrder == 'true'}">
    <c:set var="outOfStock" value="false" />
    <sql:query var="productsDataCheck" dataSource="${dataSource}">
        SELECT p.product_id, p.name, p.price, s.stock
        FROM tori_products p LEFT JOIN tori_stock s ON p.product_id = s.product_id
    </sql:query>
    <c:forEach var="product" items="${productsDataCheck.rows}">
        <c:if test="${param[product.name] > product.stock}">
            <c:set var="outOfStock" value="true" />
        </c:if>
    </c:forEach>

    <c:choose>
        <c:when test="${outOfStock}">
            <c:redirect url="index.jsp?status=stock_error" />
        </c:when>
        <c:otherwise>
            <sql:update dataSource="${dataSource}">
                INSERT INTO tori_orders (order_number, total_price, payment_amount, change_amount, status)
                VALUES (?, ?, ?, ?, 'pending')
            <sql:param value="${param.orderNumber}" />
            <sql:param value="${param.totalPrice}" />
            <sql:param value="${param.paymentAmount}" />
            <sql:param value="${param.changeAmount}" />
            </sql:update>
            
            <sql:query var="newOrderId" dataSource="${dataSource}">
                SELECT IDENTITY() AS id
            </sql:query>
            <c:set var="currentOrderId" value="${newOrderId.rows[0].id}" />

            <c:forEach var="product" items="${productsDataCheck.rows}">
                <c:if test="${param[product.name] > 0}">
                    <sql:update dataSource="${dataSource}">
                        INSERT INTO tori_order_details (order_id, product_id, quantity)
                        VALUES (?, ?, ?)                   
                    <sql:param value="${currentOrderId}" />
                    <sql:param value="${product.product_id}" />
                    <sql:param value="${param[product.name]}" />
                    </sql:update>
                    <sql:update dataSource="${dataSource}">
                        UPDATE tori_stock SET stock = stock - ? WHERE product_id = ?
                    <sql:param value="${param[product.name]}" />
                    <sql:param value="${product.product_id}" />
                    </sql:update>
                </c:if>
            </c:forEach>
            <c:redirect url="index.jsp?status=success" />
        </c:otherwise>
    </c:choose>
</c:if>

<%-- データの取得 --%>
<sql:query var="productsData" dataSource="${dataSource}">
    SELECT p.product_id, p.name, p.price, s.stock
    FROM tori_products p LEFT JOIN tori_stock s ON p.product_id = s.product_id
</sql:query>

<sql:query var="pendingOrders" dataSource="${dataSource}">
    SELECT o.order_id, o.order_number, d.quantity, p.name
    FROM tori_orders o
    JOIN tori_order_details d ON o.order_id = d.order_id
    JOIN tori_products p ON d.product_id = p.product_id
    WHERE o.status = 'pending'
    ORDER BY o.ordered_at ASC
</sql:query>

<sql:query var="salesLog" dataSource="${dataSource}">
    SELECT o.order_number, o.total_price, o.ordered_at, d.quantity, p.name
    FROM tori_orders o
    JOIN tori_order_details d ON o.order_id = d.order_id
    JOIN tori_products p ON d.product_id = p.product_id
    ORDER BY o.ordered_at DESC
</sql:query>

<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>焼き鳥POSシステム（学園祭）</title>
  <link rel="stylesheet" href="style.css" />
</head>
<body>
<nav>
  <button onclick="switchScreen('cashier')">会計</button>
  <button onclick="switchScreen('stock')">在庫</button>
  <button onclick="switchScreen('delivery')">受け渡し</button>
  <button onclick="switchScreen('log')">販売記録</button>
</nav>

<div class="screen active" id="cashier">
  <form action="index.jsp" method="get" onsubmit="return submitOrder();">
    <h2>会計処理</h2>
    <div class="yakitori-types">
      <c:forEach var="product" items="${productsData.rows}">
        <div>
          ${product.name}<br />
          <button type="button" onclick="changeCount('${product.name}', -1)">−</button>
          <span id="${product.name}Count">0</span>
          <button type="button" onclick="changeCount('${product.name}', 1)">＋</button>
        </div>
      </c:forEach>
    </div>
    <p id="totalDisplay">合計金額: ¥0</p>
    <label for="paymentInput">お預かり金額:</label>
    <input type="number" id="paymentInput" name="paymentAmount" min="0" />
    <p id="changeDisplay">お釣り: ¥0</p>
    <button type="submit">注文確定</button>
  </form>
</div>

<div class="screen" id="stock">
  <h2>在庫管理</h2>
  <ul>
    <c:forEach var="product" items="${productsData.rows}">
      <li>
        ${product.name}：<span id="stock${product.name}">${product.stock}</span>本
        <a href="index.jsp?addStock=true&productId=${product.product_id}">+200追加</a>
      </li>
    </c:forEach>
  </ul>
</div>

<div class="screen" id="delivery">
  <h2>受け渡し</h2>
  <ul id="orderList">
    <c:forEach var="order" items="${pendingOrders.rows}">
      <li>
        <span class="order-id">${order.order_number}</span>
        <label>
          <input type="checkbox" onchange="completeOrder(${order.order_id}, this)" />
          <span>${order.name}:${order.quantity}本</span>
        </label>
      </li>
    </c:forEach>
  </ul>
</div>

<div class="screen" id="log">
  <h2>販売記録</h2>
  <table id="logTable">
    <thead>
      <tr>
        <th>整理番号</th>
        <th>注文内容</th>
        <th>注文時刻</th>
      </tr>
    </thead>
    <tbody id="logList">
      <c:forEach var="log" items="${salesLog.rows}">
        <tr>
          <td>${log.order_number}</td>
          <td>${log.name}:${log.quantity}本</td>
          <td><fmt:formatDate value="${log.ordered_at}" pattern="HH:mm:ss" /></td>
        </tr>
      </c:forEach>
    </tbody>
  </table>
</div>

<script>
  let momo = 0, kawa = 0, negima = 0;

  function switchScreen(id) {
    document.querySelectorAll('.screen').forEach(el => el.classList.remove('active'));
    document.getElementById(id).classList.add('active');
    history.pushState(null, '', `?screen=${id}`);
  }

  function changeCount(type, delta) {
    if (type === 'momo') momo = Math.max(0, momo + delta);
    if (type === 'kawa') kawa = Math.max(0, kawa + delta);
    if (type === 'negima') negima = Math.max(0, negima + delta);
    updateCounts();
  }

  function updateCounts() {
    document.getElementById("momoCount").textContent = momo;
    document.getElementById("kawaCount").textContent = kawa;
    document.getElementById("negimaCount").textContent = negima;
    const total = calculatePrice(momo + kawa + negima);
    document.getElementById("totalDisplay").textContent = `合計金額: ¥${total}`;
    updateChangeDisplay();
  }

  function calculatePrice(totalCount) {
    const setPrice = 700;
    const singlePrice = 200;
    const sets = Math.floor(totalCount / 5);
    const remaining = totalCount % 5;
    return sets * setPrice + remaining * singlePrice;
  }

  function updateChangeDisplay() {
    const total = calculatePrice(momo + kawa + negima);
    const paid = parseInt(document.getElementById("paymentInput").value) || 0;
    const change = paid - total;
    document.getElementById("changeDisplay").textContent = `お釣り: ¥${change}`;
  }

  function submitOrder() {
    const totalCount = momo + kawa + negima;
    const paid = parseInt(document.getElementById("paymentInput").value);
    if (!totalCount || !paid) {
      alert("本数と金額を入力してください");
      return false;
    }

    const price = calculatePrice(totalCount);
    const change = paid - price;
    const form = document.querySelector('#cashier form');

    const hiddenInputs = {
      momo: momo,
      kawa: kawa,
      negima: negima,
      totalPrice: price,
      changeAmount: change,
      orderNumber: Math.floor(Math.random() * 10000),
      submitOrder: 'true'
    };

    for (const key in hiddenInputs) {
      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = key;
      input.value = hiddenInputs[key];
      form.appendChild(input);
    }

    alert(`注文完了\nお釣り: ¥${change}`);
    return true;
  }

  function completeOrder(orderId, checkbox) {
    if (checkbox.checked && confirm("受け渡しを完了しますか？")) {
      window.location.href = `index.jsp?completeOrder=true&orderId=${orderId}`;
    } else {
      checkbox.checked = false;
    }
  }

  document.getElementById("paymentInput").addEventListener("input", updateChangeDisplay);

  document.addEventListener('DOMContentLoaded', () => {
    updateCounts();
    const urlParams = new URLSearchParams(window.location.search);
    const currentScreen = urlParams.get('screen') || 'cashier';
    switchScreen(currentScreen);
    if (urlParams.get('status') === 'stock_error') {
      alert("在庫が不足しています。");
    }
  });
</script>
</body>
</html>
