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
        UPDATE TORI_STOCK SET STOCK = STOCK + 200 WHERE PRODUCT_ID = ?
    <sql:param value="${param.productId}" />
    </sql:update>
    <c:redirect url="index.jsp" />
</c:if>

<%-- 注文受け渡し処理: ログを削除して「済」とする --%>
<c:if test="${param.completeOrder == 'true'}">
    <sql:update dataSource="${dataSource}">
        DELETE FROM TORI_LOGS WHERE LOG_ID = ?
    <sql:param value="${param.logId}" />
    </sql:update>
    <c:redirect url="index.jsp" />
</c:if>

<%-- 注文確定処理 --%>
<c:if test="${param.submitOrder == 'true'}">
    <c:set var="outOfStock" value="false" />
    <sql:query var="productsDataCheck" dataSource="${dataSource}">
        SELECT P.PRODUCT_ID, P.NAME, P.PRICE, S.STOCK
        FROM TORI_PRODUCTS P LEFT JOIN TORI_STOCK S ON P.PRODUCT_ID = S.PRODUCT_ID
    </sql:query>
    <c:forEach var="product" items="${productsDataCheck.rows}">
        <c:if test="${param[fn:toLowerCase(product.name)] > product.stock}">
            <c:set var="outOfStock" value="true" />
        </c:if>
    </c:forEach>

    <c:choose>
        <c:when test="${outOfStock}">
            <c:redirect url="index.jsp?status=stock_error" />
        </c:when>
        <c:otherwise>
            <sql:update dataSource="${dataSource}">
                INSERT INTO TORI_LOGS (LOG_TIME, MOMO_COUNT, KAWA_COUNT, NEGIMA_COUNT, TOTAL_COUNT, PRICE, TICKET_NO)
                VALUES (NOW(), ?, ?, ?, ?, ?, ?)
            <sql:param value="${param.momo}" />
            <sql:param value="${param.皮}" />
            <sql:param value="${param.ネギま}" />
            <sql:param value="${param.totalCount}" />
            <sql:param value="${param.totalPrice}" />
            <sql:param value="${param.orderNumber}" />
            </sql:update>

            <c:forEach var="product" items="${productsDataCheck.rows}">
                <c:if test="${param[fn:toLowerCase(product.name)] > 0}">
                    <sql:update dataSource="${dataSource}">
                        UPDATE TORI_STOCK SET STOCK = STOCK - ? WHERE PRODUCT_ID = ?
                    <sql:param value="${param[fn:toLowerCase(product.name)]}" />
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
    SELECT P.PRODUCT_ID, P.NAME, P.PRICE, S.STOCK
    FROM TORI_PRODUCTS P LEFT JOIN TORI_STOCK S ON P.PRODUCT_ID = S.PRODUCT_ID
    ORDER BY P.PRODUCT_ID ASC
</sql:query>

<sql:query var="pendingOrders" dataSource="${dataSource}">
    SELECT LOG_ID, TICKET_NO, MOMO_COUNT, KAWA_COUNT, NEGIMA_COUNT FROM TORI_LOGS ORDER BY LOG_TIME ASC
</sql:query>

<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>焼き鳥レジシステム</title>
    <link rel="stylesheet" href="style.css" />
</head>
<body>
    <div class="container">
        <div class="left">
            <div class="top">
                <h2 class="section-title">会計</h2>
                <form action="index.jsp" method="post" onsubmit="return submitOrder();">
                    <div class="yakitori-table">
                        <div class="yakitori-row" data-price="150" data-name="もも">
                            <h3 class="item-name">もも</h3>
                            <div class="counter">
                                <button type="button" class="count-btn" data-action="minus">−</button>
                                <span class="count" id="momoCount">0</span>
                                <button type="button" class="count-btn" data-action="plus">＋</button>
                            </div>
                        </div>
                        <div class="yakitori-row" data-price="150" data-name="皮">
                            <h3 class="item-name">皮</h3>
                            <div class="counter">
                                <button type="button" class="count-btn" data-action="minus">−</button>
                                <span class="count" id="皮Count">0</span>
                                <button type="button" class="count-btn" data-action="plus">＋</button>
                            </div>
                        </div>
                        <div class="yakitori-row" data-price="150" data-name="ネギま">
                            <h3 class="item-name">ネギま</h3>
                            <div class="counter">
                                <button type="button" class="count-btn" data-action="minus">−</button>
                                <span class="count" id="ネギまCount">0</span>
                                <button type="button" class="count-btn" data-action="plus">＋</button>
                            </div>
                        </div>
                    </div>
                    <div id="totalAmount" class="total-display">合計金額: ¥0</div>
                    <div class="checkout-actions">
                        <label for="orderNumberInput">整理券番号:</label>
                        <input type="number" id="orderNumberInput" name="orderNumber" required />
                        <button type="submit" class="submit-button">注文確定</button>
                    </div>
                    <input type="hidden" name="submitOrder" value="true" />
                </form>
            </div>
            <div class="bottom">
                <h2 class="section-title">在庫</h2>
                <div class="stock-table">
                    <div class="table-header">
                        <div class="cell">種類</div>
                        <div class="cell">現状</div>
                        <div class="cell">追加</div>
                    </div>
                    <c:forEach var="product" items="${productsData.rows}">
                        <div class="stock-row">
                            <div class="cell">${product.name}</div>
                            <div class="cell">
                                <span class="current-stock" id="stock${product.product_id}">${product.stock}</span> 本
                            </div>
                            <a href="index.jsp?addStock=true&productId=${product.product_id}" class="cell add-stock-btn">+200</a>
                        </div>
                    </c:forEach>
                </div>
            </div>
        </div>
        <div class="right">
            <h2 class="section-title">受け渡し</h2>
            <div class="delivery-table">
                <div class="table-header">
                    <div class="cell">番号</div>
                    <div class="cell">注文内容</div>
                    <div class="cell">提供</div>
                </div>
                <div class="table-body">
                    <c:forEach var="order" items="${pendingOrders.rows}">
                        <div class="delivery-row">
                            <div class="cell">${order.ticket_no}</div>
                            <div class="cell content-cell">
                                <c:set var="yakitori_counts" value="" />
                                <c:if test="${order.momo_count > 0}">
                                    <c:set var="yakitori_counts" value="${yakitori_counts}もも: ${order.momo_count}本" />
                                </c:if>
                                <c:if test="${order.kawa_count > 0}">
                                    <c:if test="${fn:length(yakitori_counts) > 0}">
                                        <c:set var="yakitori_counts" value="${yakitori_counts}, " />
                                    </c:if>
                                    <c:set var="yakitori_counts" value="${yakitori_counts}皮: ${order.kawa_count}本" />
                                </c:if>
                                <c:if test="${order.negima_count > 0}">
                                    <c:if test="${fn:length(yakitori_counts) > 0}">
                                        <c:set var="yakitori_counts" value="${yakitori_counts}, " />
                                    </c:if>
                                    <c:set var="yakitori_counts" value="${yakitori_counts}ネギま: ${order.negima_count}本" />
                                </c:if>
                                ${yakitori_counts}
                            </div>
                            <div class="cell action-cell">
                                <button class="deliver-btn" onclick="completeOrder(${order.log_id})">×</button>
                            </div>
                        </div>
                    </c:forEach>
                </div>
            </div>
        </div>
    </div>
    <script>
        const counts = {
            'もも': 0,
            '皮': 0,
            'ネギま': 0
        };
        
        document.addEventListener('DOMContentLoaded', () => {
            const yakitoriItems = document.querySelectorAll('.yakitori-row');
            yakitoriItems.forEach(item => {
                const name = item.dataset.name;
                const countSpan = item.querySelector('.count');
                const plusBtn = item.querySelector('[data-action="plus"]');
                const minusBtn = item.querySelector('[data-action="minus"]');
    
                plusBtn.addEventListener('click', () => {
                    counts[name]++;
                    countSpan.textContent = counts[name];
                    updateTotalPrice();
                });
    
                minusBtn.addEventListener('click', () => {
                    if (counts[name] > 0) {
                        counts[name]--;
                        countSpan.textContent = counts[name];
                        updateTotalPrice();
                    }
                });
            });

            updateTotalPrice();

            const urlParams = new URLSearchParams(window.location.search);
            if (urlParams.get('status') === 'stock_error') {
                alert("在庫が不足しています。注文内容を確認してください。");
            }
        });

        function updateTotalPrice() {
            let totalCount = counts['もも'] + counts['皮'] + counts['ネギま'];
            
            const setPrice = 600;
            const singlePrice = 150;
    
            const sets = Math.floor(totalCount / 5);
            const remaining = totalCount % 5;
    
            const totalPrice = (sets * setPrice) + (remaining * singlePrice);
            document.getElementById('totalAmount').textContent = `合計金額: ¥${totalPrice}`;
        }
    
        function submitOrder() {
            const orderNumber = document.getElementById("orderNumberInput").value;
            if (!orderNumber) {
                alert("整理券番号を入力してください。");
                return false;
            }
    
            let totalItems = counts['もも'] + counts['皮'] + counts['ネギま'];
            if (totalItems === 0) {
                alert("注文する商品を選択してください。");
                return false;
            }

            const sets = Math.floor(totalItems / 5);
            const remaining = totalItems % 5;
            const totalPrice = (sets * 600) + (remaining * 150);
            
            const form = document.querySelector('form');
    
            const momoInput = document.createElement('input');
            momoInput.type = 'hidden';
            momoInput.name = 'momo';
            momoInput.value = counts['もも'];
            form.appendChild(momoInput);

            const kawaInput = document.createElement('input');
            kawaInput.type = 'hidden';
            kawaInput.name = '皮';
            kawaInput.value = counts['皮'];
            form.appendChild(kawaInput);

            const negimaInput = document.createElement('input');
            negimaInput.type = 'hidden';
            negimaInput.name = 'ネギま';
            negimaInput.value = counts['ネギま'];
            form.appendChild(negimaInput);
    
            const priceInput = document.createElement('input');
            priceInput.type = 'hidden';
            priceInput.name = 'totalPrice';
            priceInput.value = totalPrice;
            form.appendChild(priceInput);

            const totalCountInput = document.createElement('input');
            totalCountInput.type = 'hidden';
            totalCountInput.name = 'totalCount';
            totalCountInput.value = totalItems;
            form.appendChild(totalCountInput);
    
            alert(`注文番号: ${orderNumber}\n合計金額: ¥${totalPrice}\n注文を確定します。`);
            return true;
        }
    
        function completeOrder(logId) {
            if (confirm("この注文の受け渡しを完了しますか？")) {
                window.location.href = `index.jsp?completeOrder=true&logId=${logId}`;
            }
        }
    </script>
</body>
</html>
